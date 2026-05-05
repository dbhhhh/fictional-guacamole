#!/bin/bash

# 运行SCC算法并监控内存使用
# 参数1: 数据集路径
DATASET_PATH="${1:-/mnt/d/Desktop/web-Google.txt}"

echo "=== 实验开始 ==="

# 使用 time 命令运行并获取内存使用
# 创建临时脚本
TMP_SCRIPT=$(mktemp)
cat > "$TMP_SCRIPT" << 'EOF'
./bin/scc_base "$1"
EOF
chmod +x "$TMP_SCRIPT"

# 使用 /usr/bin/time 运行并捕获内存使用
OUTPUT=$(/usr/bin/time -v "$TMP_SCRIPT" "$DATASET_PATH" 2>&1)

# 清理临时脚本
rm -f "$TMP_SCRIPT"

# 输出算法结果
echo "$OUTPUT"

# 提取内存使用信息
MAX_RSS=$(echo "$OUTPUT" | grep "Maximum resident set size" | awk '{print $6}')
if [ -n "$MAX_RSS" ]; then
    MAX_RSS_MB=$((MAX_RSS / 1024))
else
    MAX_RSS_MB="未知"
fi

echo ""
echo "=== 实验结束 ==="
echo "RSS峰值: $MAX_RSS_MB MB"
