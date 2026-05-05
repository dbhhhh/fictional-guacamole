# SCC Algorithm Comparison Project

本项目用于对比分析 **强连通分量（SCC）算法** 在 GPU 平台上的性能表现。

## 算法说明

### 1. Gardenia SCC (GPU)

Gardenia 是一个高性能图计算框架，本项目使用 cuGraph API 实现的 GPU 版本 SCC 算法。

**核心文件：** `gardenia_scc_gpu.py`

**特点：**
- 基于 GPU 加速
- 使用 cuGraph 强大的图计算能力
- 适用于大规模图数据处理

### 2. cuGraph SCC

cuGraph 是 RAPIDS 生态系统的图计算库，提供了原生的 SCC 实现。

**核心文件：** `cugraph-main/run_edge_list.py`

**特点：**
- NVIDIA RAPIDS 官方库
- 深度优化 GPU 性能
- 支持多种图算法

## 数据集

本项目使用 **TLC（Transportation Learning Challenge）生成的数据集**进行算法测试。

### 测试数据集

| 数据集 | 大小 | 边数 | 说明 |
|--------|------|------|------|
| `small_test.txt` | ~0 MB | 少量 | 小规模测试数据 |
| `soc-Epinions1.txt` | 5.4 MB | 508,837 | 中等规模数据集 |
| `edge_list.txt` | 22.99 MB | 1,623,127 | 大规模数据集 |
| `Amazon0601.txt` | 45.64 MB | 3,233,163 | 大规模数据集 |
| `twitter_combined.txt` | 42.49 MB | 2,997,444 | 大规模数据集 |
| `WikiTalk.txt` | 63.39 MB | 2,394,385 | 大规模数据集 |
| `web-Google.txt` | 71.89 MB | 3,691,463 | 超大规模数据集 |

### 数据集来源

所有测试数据集均来自 SNAP（Stanford Network Analysis Project）和真实网络拓扑数据，符合 TLC 标准图格式。

**数据集格式：**
```
# 注释行（可选）
source_vertex destination_vertex
source_vertex destination_vertex
...
```

## 项目结构

```
├── run_both_algorithms.py      # 主测试脚本
├── gardenia_scc_gpu.py          # Gardenia SCC GPU 实现
├── cugraph-main/               # cuGraph 源码
│   └── run_edge_list.py        # cuGraph SCC 实现
└── gardenia-master/            # Gardenia 源码
    ├── bin/                    # 编译后的可执行文件
    └── src/                    # 源代码
```

## 使用方法

### 环境要求

- Python 3.8+
- CUDA 11.0+
- cuGraph (RAPIDS)
- WSL (Windows Subsystem for Linux)

### 运行测试

```bash
# 使用默认数据集（桌面 test 文件夹）
python run_both_algorithms.py

# 指定单个数据集
python run_both_algorithms.py d:\Desktop\test\soc-Epinions1.txt

# 指定多个数据集
python run_both_algorithms.py d:\Desktop\test\small_test.txt d:\Desktop\test\soc-Epinions1.txt
```

### 输出结果

测试完成后会生成：
- **CSV 文件**：包含所有算法的详细性能指标
- **Word 文档**：可视化对比表格和总结报告

## 性能指标

测试对比以下指标：

| 指标 | 说明 |
|------|------|
| 顶点数 | 图中顶点总数 |
| 边数 | 图中有向边总数 |
| SCC 总数 | 强连通分量数量 |
| 最大 SCC 大小 | 最大强连通分量包含的顶点数 |
| 计算时间 | 算法执行时间（秒） |
| 内存使用 | RSS 峰值内存（MB） |

## 算法原理

### 强连通分量 (Strongly Connected Components)

强连通分量是指图中的一个子集，其中任意两个顶点之间都存在路径相连。在有向图中，SCC 分析是理解图结构的重要基础。

### Kosaraju 算法

两个算法都采用基于 Kosaraju 的算法实现：
1. 第一次 DFS 获取拓扑顺序
2. 反转图
3. 第二次 DFS 按照拓扑顺序识别 SCC

## 实验环境

- **GPU**: NVIDIA RTX 3060 (6GB)
- **CPU**: 多核处理器
- **内存**: 7.6 GB
- **操作系统**: Windows 11 + WSL2

## 作者

dbhhhh

## 许可证

MIT License
