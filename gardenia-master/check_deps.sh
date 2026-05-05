#!/bin/bash
cd /mnt/d/Desktop/gardenia-master

echo "========================================="
echo "GARDENIA代码运行所需文件分析"
echo "========================================="

echo ""
echo "【1】可执行文件 (bin/)"
echo "-----------------------------------------"
ls -lh bin/

echo ""
echo "【2】数据集文件 (datasets/)"
echo "-----------------------------------------"
ls datasets/

echo ""
echo "【3】核心头文件 (include/)"
echo "-----------------------------------------"
ls include/*.h include/*.hh include/*.hpp 2>/dev/null | wc -l
echo "头文件总数:"
ls include/*.h include/*.hh include/*.hpp 2>/dev/null

echo ""
echo "【4】源代码文件 (src/)"
echo "-----------------------------------------"
echo "各模块源文件:"
for dir in src/*/; do
    if [ -d "$dir" ] && [ "$(basename $dir)" != "common.mk" ]; then
        echo "  $(basename $dir): $(ls $dir*.cc $dir*.cpp $dir*.cu 2>/dev/null | wc -l) 个源文件"
    fi
done

echo ""
echo "【5】公共源文件 (src/common/)"
echo "-----------------------------------------"
ls src/common/*.cc src/common/*.cpp 2>/dev/null

echo ""
echo "【6】第三方库 (cub/)"
echo "-----------------------------------------"
ls cub/

echo ""
echo "【7】测试文件 (test/)"
echo "-----------------------------------------"
ls test/

echo ""
echo "========================================="
echo "各算法依赖分析"
echo "========================================="

echo ""
echo "【CC算法】依赖的头文件:"
grep -h '#include' src/cc/*.cc src/cc/*.cpp 2>/dev/null | grep '"' | sed 's/.*#include "\(.*\)".*/\1/' | sort -u

echo ""
echo "【PR算法】依赖的头文件:"
grep -h '#include' src/pr/*.cc src/pr/*.cpp 2>/dev/null | grep '"' | sed 's/.*#include "\(.*\)".*/\1/' | sort -u

echo ""
echo "【BFS算法】依赖的头文件:"
grep -h '#include' src/bfs/*.cc src/bfs/*.cpp 2>/dev/null | grep '"' | sed 's/.*#include "\(.*\)".*/\1/' | sort -u

echo ""
echo "【SCC算法】依赖的头文件:"
grep -h '#include' src/scc/*.cc src/scc/*.cpp 2>/dev/null | grep '"' | sed 's/.*#include "\(.*\)".*/\1/' | sort -u

echo ""
echo "【TC算法】依赖的头文件:"
grep -h '#include' src/tc/*.cc src/tc/*.cpp 2>/dev/null | grep '"' | sed 's/.*#include "\(.*\)".*/\1/' | sort -u