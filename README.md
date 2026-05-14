# Fictional Guacamole

## 项目概述

本项目包含以下三个主要部分：
1. **SCC 算法性能对比** - Gardenia 与 cuGraph 的 GPU 强连通分量算法对比
2. **TLA+ 规范与示例** - TLA+ 形式化规范和从模型生成的图数据
3. **图计算框架源码** - Gardenia 和 cuGraph 完整源码

## 目录结构

```
.
├── gardenia_scc_gpu.py              # Gardenia SCC GPU 实现
├── gardenia_scc_gpu_optimized.py    # Gardenia SCC 优化版本
├── run_both_algorithms.py           # SCC 算法对比测试脚本
├── test/                            # 测试数据集目录
│   ├── edge_list.txt                # 边列表数据
│   ├── p2p-Gnutella08.txt           # Gnutella P2P 网络数据
│   └── edge_list_*.txt              # 各 TLA+ 模型的边列表
├── tlc/                             # TLA+ 规范目录
│   ├── *.tla                        # TLA+ 规范文件
│   ├── edge_list_*.txt              # 从模型生成的边列表
│   ├── states/                      # TLC 模型检查状态文件
│   ├── examples/                    # TLA+ 完整示例
│   └── specifications.py            # 规范配置
├── cugraph-main/                    # cuGraph RAPIDS 图计算库
│   ├── run_edge_list.py            # cuGraph SCC 实现
│   ├── cpp/                        # C++/CUDA 核心实现
│   ├── python/                     # Python API
│   └── cugra实验结果_*.txt         # cuGraph 实验结果
└── gardenia-master/                 # Gardenia 图计算框架
    ├── src/                        # 图算法源码 (BFS, SCC, PageRank等)
    ├── mining/                     # 图挖掘算法
    ├── datasets/                   # 测试数据集
    └── cub/                       # CUB GPU 库
```

## 主要内容

### 1. SCC 算法对比

**核心脚本：**
- [gardenia_scc_gpu.py](gardenia_scc_gpu.py) - Gardenia cuGraph SCC 实现
- [gardenia_scc_gpu_optimized.py](gardenia_scc_gpu_optimized.py) - 优化版本
- [cugraph-main/run_edge_list.py](cugraph-main/run_edge_list.py) - cuGraph 原生 SCC
- [run_both_algorithms.py](run_both_algorithms.py) - 对比测试脚本

**使用方式：**
```bash
python run_both_algorithms.py
```

### 2. TLA+ 规范与示例

**根目录规范文件：**
- [tlc/DieHard.tla](tlc/DieHard.tla) - DieHard 问题规范
- [tlc/MissionariesAndCannibals.tla](tlc/MissionariesAndCannibals.tla) - 传教士与食人者问题
- [tlc/MultiPaxos.tla](tlc/MultiPaxos.tla) - MultiPaxos 共识算法
- [tlc/Nano.tla](tlc/Nano.tla) - NanoBlockchain 规范
- [tlc/ReadersWriters.tla](tlc/ReadersWriters.tla) - 读者写者问题
- [tlc/EWD840.tla](tlc/EWD840.tla) - EWD840 分布式算法
- [tlc/SyncTerminationDetection.tla](tlc/SyncTerminationDetection.tla) - 同步终止检测

**examples/ 完整示例：**
- [tlc/examples/DieHard/](tlc/examples/DieHard/) - DieHard 完整示例
- [tlc/examples/MissionariesAndCannibals/](tlc/examples/MissionariesAndCannibals/) - 传教士与食人者
- [tlc/examples/MultiPaxos-SMR/](tlc/examples/MultiPaxos-SMR/) - MultiPaxos SMR 实现
- [tlc/examples/NanoBlockchain/](tlc/examples/NanoBlockchain/) - NanoBlockchain 实现
- [tlc/examples/ReadersWriters/](tlc/examples/ReadersWriters/) - 读者写者问题
- [tlc/examples/ewd840/](tlc/examples/ewd840/) - EWD840 分布式算法

### 3. Gardenia 图计算框架

[gardenia-master/](gardenia-master/) 包含多种图算法实现：

**图分析算法：**
- BFS (广度优先搜索)
- SCC (强连通分量)
- PageRank
- SSSP (单源最短路径)
- CC (连通分量)
- BC (介数中心性)
- MST (最小生成树)
- SpMV (稀疏矩阵向量乘)
- VC (顶点着色)
- SymGS (对称高斯-赛德尔平滑)

**图挖掘算法：**
- FSM (频繁子图挖掘)
- KCL (K-Core 查询)
- Motif (Motif 计数)
- SGL (子图匹配)

### 4. cuGraph RAPIDS

[cugraph-main/](cugraph-main/) 是 RAPIDS cuGraph 库的完整源码和实验数据。

## 环境要求

- Python 3.8+
- CUDA 11.0+ (GPU 计算)
- cuGraph (RAPIDS)
- TLA+ Toolbox (用于 TLC 模型检查)

## 作者

dbhhhh

## 许可证

MIT License
