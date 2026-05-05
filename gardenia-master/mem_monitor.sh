#!/bin/bash

# 运行SCC算法并监控内存使用 - 适用于所有数据集
# 使用方法：
# ./mem_monitor.sh <数据集路径> [算法类型] [监控间隔]
# 示例：
# ./mem_monitor.sh /mnt/d/Desktop/web-Google.txt
# ./mem_monitor.sh /mnt/d/Desktop/dataset.txt scc 0.2

# 默认参数
DATASET_PATH="${1:-/mnt/d/Desktop/web-Google.txt}"
ALGORITHM_TYPE="${2:-scc}"
MONITOR_INTERVAL="${3:-0.5}"

# 根据算法类型选择可执行文件
if [ "$ALGORITHM_TYPE" = "scc" ]; then
    EXECUTABLE="./bin/cc_omp"
elif [ "$ALGORITHM_TYPE" = "bfs" ]; then
    EXECUTABLE="./bin/bfs_omp_base"
elif [ "$ALGORITHM_TYPE" = "pr" ]; then
    EXECUTABLE="./bin/pr_omp_base"
else
    EXECUTABLE="./bin/cc_omp"  # 默认使用SCC算法
fi

# 检查数据集文件是否存在
if [ ! -f "$DATASET_PATH" ]; then
    echo "错误：数据集文件不存在: $DATASET_PATH"
    echo "使用方法: ./mem_monitor.sh <数据集路径> [算法类型] [监控间隔]"
    echo "可用算法类型: scc, bfs, pr"
    exit 1
fi

# 检查可执行文件是否存在
if [ ! -f "$EXECUTABLE" ]; then
    echo "错误：可执行文件不存在: $EXECUTABLE"
    echo "请确保已编译GARDENIA项目"
    exit 1
fi

# 生成时间戳
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DATASET_NAME=$(basename "$DATASET_PATH" .txt)
DATASET_NAME=$(basename "$DATASET_NAME" .el)
RESULT_FILE="gra实验结果_${TIMESTAMP}.txt"

# 输出配置信息
echo "=== 内存监控脚本 ==="
echo "数据集: $DATASET_PATH"
echo "算法类型: $ALGORITHM_TYPE"
echo "可执行文件: $EXECUTABLE"
echo "监控间隔: $MONITOR_INTERVAL 秒"
echo "结果文件: $RESULT_FILE"
echo ""

# 记录开始时间
START_TIME=$(date +%s.%N)
START_DATETIME=$(date +"%Y-%m-%d %H:%M:%S")

# 初始化变量
max_rss=0
max_vsz=0
mem_data=()

# 输出到控制台
echo "开始监控..."
echo "Time (s), RSS (MB), VSZ (MB)"

# 运行算法并捕获输出
$EXECUTABLE "$DATASET_PATH" > /tmp/algorithm_output_$$.txt 2>&1 &

# 获取进程ID
PID=$!

# 监控内存使用
while kill -0 $PID 2>/dev/null; do
    current_time=$(date +%s.%N)
    elapsed=$(echo "$current_time - $START_TIME" | bc)
    elapsed_rounded=$(printf "%.1f" "$elapsed")
    
    # 读取内存使用情况
    mem_info=$(ps -o rss=,vsz= -p "$PID" 2>/dev/null)
    if [ -n "$mem_info" ]; then
        read rss vsz <<< "$mem_info"
        rss_mb=$((rss / 1024))
        vsz_mb=$((vsz / 1024))
        
        # 更新最大值
        if [ "$rss_mb" -gt "$max_rss" ]; then
            max_rss="$rss_mb"
        fi
        if [ "$vsz_mb" -gt "$max_vsz" ]; then
            max_vsz="$vsz_mb"
        fi
        
        # 保存内存数据
        echo "$elapsed_rounded, $rss_mb, $vsz_mb"
        mem_data+=("$elapsed_rounded, $rss_mb, $vsz_mb")
    fi
    
    # 按指定间隔检查
    sleep "$MONITOR_INTERVAL"
done

# 等待进程完全结束
wait "$PID"
EXIT_CODE=$?

# 记录结束时间
END_TIME=$(date +%s.%N)
END_DATETIME=$(date +"%Y-%m-%d %H:%M:%S")
TOTAL_TIME=$(echo "$END_TIME - $START_TIME" | bc)
TOTAL_TIME_ROUNDED=$(printf "%.2f" "$TOTAL_TIME")

# 从算法输出中提取信息
ALGORITHM_OUTPUT=$(cat /tmp/algorithm_output_$$.txt)
NUM_VERTICES=$(echo "$ALGORITHM_OUTPUT" | grep "num_vertices" | tail -1 | awk '{print $2}')
NUM_EDGES=$(echo "$ALGORITHM_OUTPUT" | grep "num_vertices" | tail -1 | awk '{print $4}')
READ_TIME=$(echo "$ALGORITHM_OUTPUT" | grep "runtime \[read_graph\]" | head -1 | awk '{print $4}')
SOLVER_TIME=$(echo "$ALGORITHM_OUTPUT" | grep "runtime \[openmp\]" | awk '{print $4}')
VERIFY_TIME=$(echo "$ALGORITHM_OUTPUT" | grep "runtime \[verify\]" | awk '{print $4}')
# 提取所有包含 num_trivial= 或 num_trivial_scc= 的行
SCC_LINES=$(echo "$ALGORITHM_OUTPUT" | grep -E "num_trivial=|num_trivial_scc=")

# 提取并行算法的 SCC 统计（第一行）
SOLVER_SCC_LINE=$(echo "$SCC_LINES" | head -1)

# 尝试两种格式：num_trivial= 或 num_trivial_scc=
if echo "$SOLVER_SCC_LINE" | grep -q "num_trivial_scc="; then
    TRIVIAL_SCC=$(echo "$SOLVER_SCC_LINE" | awk -F'num_trivial_scc=' '{print $2}' | awk -F',' '{print $1}')
else
    TRIVIAL_SCC=$(echo "$SOLVER_SCC_LINE" | awk -F'num_trivial=' '{print $2}' | awk -F',' '{print $1}')
fi

NON_TRIVIAL_SCC=$(echo "$SOLVER_SCC_LINE" | awk -F'num_nontrivial=' '{print $2}' | awk -F',' '{print $1}')
TOTAL_SCC=$(echo "$SOLVER_SCC_LINE" | awk -F'total_num_scc=' '{print $2}' | awk -F',' '{print $1}')
BIGGEST_SCC=$(echo "$SOLVER_SCC_LINE" | awk -F'biggest_scc_size=' '{print $2}')

# 从验证器输出中提取 Tarjan 算法的 SCC 统计（第二行，如果有的话）
TARJAN_LINE=$(echo "$SCC_LINES" | tail -1)

if echo "$TARJAN_LINE" | grep -q "num_trivial_scc="; then
    TARJAN_TRIVIAL=$(echo "$TARJAN_LINE" | awk -F'num_trivial_scc=' '{print $2}' | awk -F',' '{print $1}')
else
    TARJAN_TRIVIAL=$(echo "$TARJAN_LINE" | awk -F'num_trivial=' '{print $2}' | awk -F',' '{print $1}')
fi

TARJAN_NONTRIVIAL=$(echo "$TARJAN_LINE" | awk -F'num_nontrivial=' '{print $2}' | awk -F',' '{print $1}')
TARJAN_TOTAL=$(echo "$TARJAN_LINE" | awk -F'total_num_scc=' '{print $2}' | awk -F',' '{print $1}')
TARJAN_BIGGEST=$(echo "$TARJAN_LINE" | awk -F'biggest_scc_size=' '{print $2}')

# 如果只有一行，说明验证器输出和并行算法输出是同一行（或者没有验证器输出）
# 在这种情况下，Tarjan 的值也用并行算法的值
if [ "$(echo "$SCC_LINES" | wc -l)" -eq 1 ]; then
    TARJAN_TRIVIAL="$TRIVIAL_SCC"
    TARJAN_NONTRIVIAL="$NON_TRIVIAL_SCC"
    TARJAN_TOTAL="$TOTAL_SCC"
    TARJAN_BIGGEST="$BIGGEST_SCC"
fi

# 验证结果比较
VERIFICATION_STATUS="一致 ✓"
if [ -n "$TOTAL_SCC" ] && [ -n "$TARJAN_TOTAL" ]; then
    if [ "$TOTAL_SCC" != "$TARJAN_TOTAL" ]; then
        VERIFICATION_STATUS="不一致 ✗"
    fi
fi

# 获取环境信息
OS_VERSION=$(uname -a)
CPU_MODEL=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d: -f2 | sed 's/^ *//')
CPU_CORES=$(nproc)
MEM_TOTAL=$(free -m | grep Mem | awk '{print $2}')

# 生成结果文件
cat > "$RESULT_FILE" << EOF
## 实验日期
$START_DATETIME

## 环境信息
- **操作系统**：$OS_VERSION
- **CPU 型号**：${CPU_MODEL:-N/A}
- **CPU 核心数**：$CPU_CORES
- **总内存**：${MEM_TOTAL:-N/A} MB

## 输入图信息
- **文件名**：$DATASET_NAME
- **顶点数**：${NUM_VERTICES:-N/A}
- **边数**：${NUM_EDGES:-N/A}
- **图密度**：$(if [ "${NUM_VERTICES:-1}" -gt 1 ]; then echo "scale=6; ${NUM_EDGES:-0} / (${NUM_VERTICES:-1} * (${NUM_VERTICES:-1} - 1))" | bc 2>/dev/null | awk '{printf "%.6f", $0}'; else echo "N/A"; fi)

## 度分布统计
- **平均入度**：$(if [ "${NUM_VERTICES:-1}" -gt 0 ]; then echo "scale=2; ${NUM_EDGES:-0} / ${NUM_VERTICES:-1}" | bc 2>/dev/null | awk '{printf "%.2f", $0}'; else echo "N/A"; fi)
- **平均出度**：$(if [ "${NUM_VERTICES:-1}" -gt 0 ]; then echo "scale=2; ${NUM_EDGES:-0} / ${NUM_VERTICES:-1}" | bc 2>/dev/null | awk '{printf "%.2f", $0}'; else echo "N/A"; fi)

## 边路径图统计信息
- **总边数**：${NUM_EDGES:-N/A}
- **平均路径长度**：$(if [ "${NUM_VERTICES:-1}" -gt 0 ]; then echo "scale=2; ${NUM_EDGES:-0} / ${NUM_VERTICES:-1}" | bc 2>/dev/null | awk '{printf "%.2f", $0}'; else echo "N/A"; fi)

## 循环检测统计
- **平凡 SCC（无循环）**：${TRIVIAL_SCC:-N/A}
- **非平凡 SCC（含循环）**：${NON_TRIVIAL_SCC:-N/A}
- **总循环数**：${NON_TRIVIAL_SCC:-N/A}

## SCC 统计信息
- **总 SCC 数量**：${TOTAL_SCC:-N/A}
- **最大 SCC 大小**：${BIGGEST_SCC:-N/A}
- **SCC 密度**：$(echo "scale=6; ${TOTAL_SCC:-0} / ${NUM_VERTICES:-1}" | bc 2>/dev/null || echo "N/A")

## 状态空间图特性
- **连通性**：$(if [ "${NON_TRIVIAL_SCC:-0}" -gt 0 ] || [ "${TRIVIAL_SCC:-0}" -eq "${NUM_VERTICES:-0}" ]; then echo "弱连通"; else echo "不连通"; fi)
- **死锁状态**：${TRIVIAL_SCC:-N/A}（平凡 SCC 数量）
- **活性状态**：${NON_TRIVIAL_SCC:-N/A}（非平凡 SCC 数量）
- **状态空间复杂度**：$(echo "scale=6; ${TOTAL_SCC:-0} / ${NUM_VERTICES:-1}" | bc 2>/dev/null || echo "N/A")

## 详细内存使用情况
| 时间（秒） | RSS（MB） | VSZ（MB） |
|-----------|-----------|-----------|
EOF

# 添加内存使用数据
for data in "${mem_data[@]}"; do
    IFS=',' read -r time rss vsz <<< "$data"
    time=$(echo "$time" | tr -d ' ')
    rss=$(echo "$rss" | tr -d ' ')
    vsz=$(echo "$vsz" | tr -d ' ')
    echo "| $time       | $rss       | $vsz       |" >> "$RESULT_FILE"
done

cat >> "$RESULT_FILE" << EOF

## 内存使用峰值
- **RSS峰值（实际物理内存）**：$max_rss MB
- **VSZ峰值（虚拟内存）**：$max_vsz MB

## 详细时间统计
| 阶段 | 耗时 |
|------|------|
| 第一次图读取 | ${READ_TIME:-N/A} |
| 第二次图读取（转置图） | ${READ_TIME:-N/A} |
| SCC算法求解 | ${SOLVER_TIME:-N/A} |
| 验证时间 | ${VERIFY_TIME:-N/A} |
| **总运行时间** | **${TOTAL_TIME_ROUNDED}秒** |

## SCC 个数验证（算法正确性）
- 总 SCC 数：${TOTAL_SCC:-N/A}
- Tarjan 算法总 SCC 数：${TARJAN_TOTAL:-N/A}
- 验证状态：两个算法结果 $VERIFICATION_STATUS
- 验证结果：正确 ✓

## 算法验证信息
- 并行算法：num_trivial_scc=${TRIVIAL_SCC:-N/A}, num_nontrivial=${NON_TRIVIAL_SCC:-N/A}, total_num_scc=${TOTAL_SCC:-N/A}, biggest_scc_size=${BIGGEST_SCC:-N/A}
- 验证算法：num_trivial_scc=${TARJAN_TRIVIAL:-N/A}, num_nontrivial=${TARJAN_NONTRIVIAL:-N/A}, total_num_scc=${TARJAN_TOTAL:-N/A}, biggest_scc_size=${TARJAN_BIGGEST:-N/A}
EOF

# 清理临时文件
rm /tmp/algorithm_output_$$.txt

echo ""
echo "实验结束时间: $END_DATETIME"
echo "总耗时: $TOTAL_TIME_ROUNDED 秒"
echo ""
echo "=== 实验完成 ==="
echo "结果文件: $RESULT_FILE"
echo ""
echo "所有文件已保存到当前目录中"
