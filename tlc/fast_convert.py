#!/usr/bin/env python3
"""
快速DOT格式转边列表转换工具
支持多种规约选项
"""
import re
import sys
from specifications import get_specification, list_specifications

def parse_dot_file(dot_file):
    """
    解析DOT文件，提取节点和边信息
    Returns: (node_map, edges)
    """
    node_map = {}
    node_id = 0
    edges = []

    with open(dot_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            
            # 跳过空行和注释
            if not line or line.startswith('//'):
                continue

            # 解析节点定义：格式如 "12345 [label=...]"
            node_match = re.match(r'^\s*([-+]?\d+)\s*\[', line)
            if node_match:
                node_num = node_match.group(1)
                if node_num and node_num not in node_map:
                    node_map[node_num] = node_id
                    node_id += 1
                continue

            # 解析边定义：格式如 "123 -> 456 [label=...]"
            edge_match = re.match(r'^\s*([-+]?\d+)\s*->\s*([-+]?\d+)', line)
            if edge_match:
                src = edge_match.group(1)
                dst = edge_match.group(2)
                if src and dst:
                    edges.append((src, dst))
                continue

    return node_map, edges

def write_edge_list(edge_file, node_map, edges):
    """写入边列表文件"""
    with open(edge_file, 'w', encoding='utf-8') as f:
        for src, dst in edges:
            if src in node_map and dst in node_map:
                f.write(f"{node_map[src]} {node_map[dst]}\n")

def write_node_mapping(node_file, node_map):
    """写入节点映射文件"""
    with open(node_file, 'w', encoding='utf-8') as f:
        for node_num, idx in sorted(node_map.items(), key=lambda x: x[1]):
            f.write(f"{idx}: {node_num}\n")

def convert(dot_file, edge_file, spec_name='default', verbose=True):
    """
    执行DOT到边列表的转换

    Args:
        dot_file: 输入DOT文件名
        edge_file: 输出边列表文件名
        spec_name: 规约名称
        verbose: 是否输出详细信息
    """
    spec = get_specification(spec_name)
    node_file = edge_file.replace('.txt', '_nodes.txt')

    if verbose:
        if spec:
            print(f"规约: {spec.description}")
        else:
            print(f"规约: {spec_name} (未找到配置文件)")
        print(f"读取文件: {dot_file}")

    node_map, edges = parse_dot_file(dot_file)

    if verbose:
        print(f"解析完成: {len(node_map)} 个节点, {len(edges)} 条边")
        print(f"写入文件: {edge_file}")

    write_edge_list(edge_file, node_map, edges)
    write_node_mapping(node_file, node_map)

    if verbose:
        print(f"节点映射: {node_file}")
        print("转换完成!")

    return node_map, edges

def main():
    if len(sys.argv) < 3:
        print("用法: python fast_convert.py <dot_file> <edge_file> [spec_name]")
        print("\n可选规约:")
        list_specifications()
        print("\n示例:")
        print("  python fast_convert.py state_graph.dot edge_list.txt")
        print("  python fast_convert.py state_graph.dot edge_list.txt diehard")
        sys.exit(1)

    dot_file = sys.argv[1]
    edge_file = sys.argv[2]
    spec_name = sys.argv[3] if len(sys.argv) > 3 else 'default'

    convert(dot_file, edge_file, spec_name)

if __name__ == "__main__":
    main()
