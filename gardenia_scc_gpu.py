#!/usr/bin/env python3
import sys
import time
import cudf
import cugraph
from cugraph import strongly_connected_components
import argparse
import os
import resource

def scc_cugraph(filename):
    print(f"=== Gardenia SCC (GPU) ===")
    
    print("  读取文件...")
    start_time = time.time()
    
    skip_rows = 0
    with open(filename, 'r') as f:
        first_line = f.readline().strip()
        while first_line.startswith('#'):
            skip_rows += 1
            first_line = f.readline().strip()
            if not first_line:
                break
    
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
    
    del G
    del df
    del scc_df
    
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
    parser = argparse.ArgumentParser(description='GPU SCC using cuGraph')
    parser.add_argument('filename', help='Input graph file')
    args = parser.parse_args()
    
    print("=== Gardenia SCC GPU 实验开始 ===")
    
    try:
        results = scc_cugraph(args.filename)
        print("=== 实验结束 ===")
    except Exception as e:
        print(f"❌ 实验失败: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)