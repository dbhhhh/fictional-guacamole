import cudf
import cugraph
import sys

print("=== cuGraph 测试脚本 ===")
print(f"Python 版本: {sys.version}")
print()

# 测试 1: 检查导入
try:
    import cudf
    import cugraph
    print("✅ 成功导入 cudf 和 cugraph")
    print(f"   cuDF 版本: {cudf.__version__}")
    print(f"   cuGraph 版本: {cugraph.__version__}")
except ImportError as e:
    print(f"❌ 导入失败: {e}")
    sys.exit(1)

print()

# 测试 2: 创建一个简单的图
try:
    print("=== 创建简单图 ===")
    # 创建一个示例边列表
    edges = cudf.DataFrame({
        'src': [0, 1, 2, 2, 3, 3],
        'dst': [1, 2, 0, 3, 0, 1]
    })
    print("   边列表:")
    print(edges)
    print()
    
    # 创建图
    G = cugraph.Graph()
    G.from_cudf_edgelist(edges, source='src', destination='dst')
    print("✅ 成功创建图")
    print(f"   顶点数量: {G.number_of_vertices()}")
    print(f"   边数量: {G.number_of_edges()}")
except Exception as e:
    print(f"❌ 创建图失败: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print()

# 测试 3: 运行 PageRank
try:
    print("=== 运行 PageRank ===")
    pr_df = cugraph.pagerank(G)
    print("✅ 成功运行 PageRank")
    print("   结果:")
    print(pr_df.sort_values('pagerank', ascending=False))
except Exception as e:
    print(f"❌ PageRank 失败: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print()
print("🎉 所有测试通过！cuGraph 运行正常！")
