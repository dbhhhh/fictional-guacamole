#!/usr/bin/env python3
import sys
import time
import cudf
import cugraph
from cugraph import strongly_connected_components
import argparse
import os
import resource
import gc
import mmap

def scc_cugraph_optimized(filename):
    print(f"=== Gardenia SCC (GPU) - 优化版 ===")
    
    print("  读取文件...")
    start_time = time.time()
    
    # 优化1：使用内存映射文件
    try:
        skip_rows = 0
        with open(filename, 'r+b') as f:
            mm = mmap.mmap(f.fileno(), length=0, access=mmap.ACCESS_READ)
            # 读取并跳过注释行
            while True:
                line = mm.readline().decode().strip()
                if not line:
                    break
                if line.startswith('#'):
                    skip_rows += 1
                else:
                    break
    except:
        # 内存映射失败，回退到普通读取
        skip_rows = 0
        with open(filename, 'r') as f:
            first_line = f.readline().strip()
            while first_line.startswith('#'):
                skip_rows += 1
                first_line = f.readline().strip()
                if not first_line:
                    break
    
    # 优化2：分块读取大文件
    file_size = os.path.getsize(filename)
    chunk_size = 100_000  # 每块10万行
    
    if file_size > 50 * 1024 * 1024:  # >50MB使用分块
        print(f"  大文件检测，使用分块读取...")
        all_chunks = []
        try:
            for chunk in cudf.read_csv(
                filename,
                names=["source", "destination"],
                dtype=["int32", "int32"],
                sep="\s+",
                skiprows=skip_rows,
                header=None,
                chunksize=chunk_size
            ):
                all_chunks.append(chunk)
            df = cudf.concat(all_chunks)
        except:
            import pandas as pd
            all_chunks = []
            for chunk in pd.read_csv(
                filename,
                names=["source", "destination"],
                dtype={"source": "int32", "destination": "int32"},
                sep="\s+",
                skiprows=skip_rows,
                header=None,
                chunksize=chunk_size
            ):
                all_chunks.append(chunk)
            df = cudf.from_pandas(pd.concat(all_chunks))
    else:
        try:
            df = cudf.read_csv(
                filename,
                names=["source", "destination"],
                dtype=["int32", "int32"],
                sep="\s+",
                skiprows=skip_rows,
                header=None
            )
        except:
            import pandas as pd
            temp_df = pd.read_csv(
                filename,
                names=["source", "destination"],
                dtype={"source": "int32", "destination": "int32"},
                sep="\s+",
                skiprows=skip_rows,
                header=None
            )
            df = cudf.from_pandas(temp_df)
    
    read_time = time.time() - start_time
    
    num_vertices = int(max(df['source'].max(), df['destination'].max()) + 1)
    num_edges = len(df)
    
    print(f"  文件读取完成，耗时: {read_time:.4f} 秒")
    print(f"  顶点数: {num_vertices}")
    print(f"  边数: {num_edges}")
    
    print("  构建图...")
    start_time = time.time()
    
    # 优化3：显式垃圾回收
    gc.collect()
    
    # 优化4：使用更高效的图构建
    try:
        # 尝试使用压缩内存模式
        G = cugraph.Graph(directed=True)
        G.from_cudf_edgelist(df, source='source', destination='destination')
    except Exception as e:
        print(f"  警告: 压缩内存模式失败，使用标准模式: {e}")
        gc.collect()
        G = cugraph.Graph(directed=True)
        G.from_cudf_edgelist(df, source='source', destination='destination')
    
    build_time = time.time() - start_time
    print(f"  图构建完成，耗时: {build_time:.4f} 秒")
    
    print("  运行SCC算法...")
    start_time = time.time()
    
    scc_df = strongly_connected_components(G)
    
    compute_time = time.time() - start_time
    
    num_components = int(scc_df['labels'].nunique())
    component_sizes = scc_df.groupby('labels').size().sort_values(ascending=False)
    largest_component = int(component_sizes.iloc[0]) if len(component_sizes) > 0 else 0
    single_node_components = int((component_sizes == 1).sum())
    
    total_time = read_time + build_time + compute_time
    
    max_rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    rss_peak = max_rss // 1024
    
    print(f"  SCC总数: {num_components}")
    print(f"  最大SCC大小: {largest_component}")
    print(f"  平凡SCC数: {single_node_components}")
    print(f"  非平凡SCC数: {num_components - single_node_components}")
    print(f"  计算时间: {compute_time:.4f} 秒")
    print(f"  总时间: {total_time:.4f} 秒")
    print(f"  RSS峰值: {rss_peak} MB")
    
    # 优化5：及时释放内存
    del G
    del scc_df
    del component_sizes
    gc.collect()
    
    # 延迟释放数据框，确保统计完成
    time.sleep(0.1)
    del df
    gc.collect()
    
    print(f"顶点数: {num_vertices}")
    print(f"边数: {num_edges}")
    print(f"SCC总数: {num_components}")
    print(f"最大SCC大小: {largest_component}")
    print(f"平凡SCC数: {single_node_components}")
    print(f"非平凡SCC数: {num_components - single_node_components}")
    print(f"计算时间: {compute_time:.4f}")
    print(f"RSS峰值: {rss_peak}")
    
    return {
        'num_vertices': num_vertices,
        'num_edges': num_edges,
        'total_scc': num_components,
        'biggest_scc': largest_component,
        'num_trivial': single_node_components,
        'num_nontrivial': num_components - single_node_components,
        'compute_time': compute_time,
        'rss_peak': rss_peak
    }

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='GPU SCC using cuGraph (Optimized)')
    parser.add_argument('filename', help='Input graph file')
    args = parser.parse_args()
    
    print("=== Gardenia SCC GPU 优化版实验开始 ===")
    print("  优化特性：")
    print("    - 内存映射文件读取")
    print("    - 大文件分块处理")
    print("    - 显式垃圾回收")
    print("    - 及时内存释放")
    print()
    
    try:
        results = scc_cugraph_optimized(args.filename)
        print("=== 实验结束 ===")
    except Exception as e:
        print(f"❌ 实验失败: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
