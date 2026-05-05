# TLC状态图生成工具

## 概述
本工具使用TLC模型检查器生成指定状态数的状态图，并可以将输出保存为多种格式，包括TLC原生输出、DOT格式和边列表格式（适用于SCC算法）。只需修改一个参数即可调整生成的状态数！

## 文件说明
- `StateGen.tla` - TLA+规范文件，定义状态机模型
- `StateGen.cfg` - TLC配置文件，只需修改MaxValue一个参数
- `run_tlc.ps1` - PowerShell脚本，用于运行TLC并保存原生输出
- `generate_edgelist.ps1` - PowerShell脚本，生成边列表格式（用于SCC算法）
- `fast_convert.py` - 快速Python转换脚本（推荐用于大文件）
- `convert_dot.ps1` - PowerShell转换脚本（用于小文件）
- `tla2tools.jar` - TLA+工具包

## 使用方法

### 1. 调整状态数（只需修改一个参数！）
打开 `StateGen.cfg` 并修改 `MaxValue` 的值：
```
CONSTANTS
    MaxValue = 79
```

状态总数计算公式：
```
状态总数 = (MaxValue + 1) × (MaxValue + 1) × (MaxValue + 1)
```

### 2. 常见配置示例

- **约500,000个状态**：MaxValue=79 (80×80×80=512,000)
- **约100,000个状态**：MaxValue=46 (47×47×47=103,823)
- **约1,000,000个状态**：MaxValue=99 (100×100×100=1,000,000)
- **约10,000个状态**：MaxValue=21 (22×22×22=10,648)
- **测试（27个状态）**：MaxValue=2 (3×3×3=27)

### 3. 生成边列表格式（用于SCC算法）

如果你需要边列表格式来运行SCC（强连通分量）算法，按以下步骤操作：

#### 系统要求
- Java 8或更高版本
- Windows PowerShell
- Python 3.x（推荐，处理大文件更快）

#### 步骤
1. 确保已安装Python 3
2. 在PowerShell中执行：
```powershell
powershell -ExecutionPolicy Bypass -File .\generate_edgelist.ps1
```

#### 生成的文件
脚本会生成以下三个文件：
- `state_graph.dot` - DOT格式的状态图
- `edge_list.txt` - 边列表格式（适用于SCC算法）
- `edge_list_nodes.txt` - 节点ID映射表

#### 边列表格式说明
`edge_list.txt` 格式：每行两个整数，表示一条有向边
```
0 1
0 2
1 3
1 4
...
```

`edge_list_nodes.txt` 格式：节点ID到TLC内部编号的映射
```
0: -1434755284208880453
1: -1124629676264697892
...
```

### 4. 运行TLC（原生输出）
在PowerShell中执行：
```powershell
powershell -ExecutionPolicy Bypass -File .\run_tlc.ps1
```

输出将自动保存为 `tlc_output_YYYYMMDD_HHmmss.txt` 格式的文件。

### 5. 查看结果
- **TLC原生输出**：包含完整的TLC运行输出，包括状态探索统计、发现的不同状态数、运行时间等信息
- **边列表输出**：适用于SCC等图算法

## 性能优化说明

### 为什么处理大文件会慢？

当 `MaxValue=79` 时，会生成：
- **512,000个状态**（80×80×80）
- **约150万条边**（每个状态平均约3条出边）
- DOT文件可能达到 **50-100MB**

这导致处理时间较长是正常的。

### 优化建议

1. **使用Python转换脚本**：我们已切换到 `fast_convert.py`，它比PowerShell快很多
2. **从小配置开始测试**：先用 `MaxValue=2` 或 `MaxValue=10` 测试整个流程
3. **耐心等待**：500k状态的生成和转换可能需要几分钟
4. **进度提示**：Python脚本会显示处理进度，每10,000个节点和每100,000条边都会提示

### 手动使用Python转换（可选）

如果需要手动转换：
```powershell
python fast_convert.py state_graph.dot edge_list.txt
```

## 系统要求
- Java 8或更高版本
- Windows PowerShell
- Python 3.x（推荐用于处理大文件）

## 注意事项
- 较大的状态数会消耗更多内存和时间
- 建议从较小的配置开始测试
- 生成边列表格式推荐使用Python以获得更好性能
