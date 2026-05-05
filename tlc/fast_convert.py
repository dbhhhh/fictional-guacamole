#!/usr/bin/env python3
import re
import sys

def main():
    if len(sys.argv) < 3:
        print("Usage: python fast_convert.py <dot_file> <edge_file>")
        print("Example: python fast_convert.py state_graph.dot edge_list.txt")
        sys.exit(1)
    
    dot_file = sys.argv[1]
    edge_file = sys.argv[2]
    node_file = edge_file.replace('.txt', '_nodes.txt')
    
    node_map = {}
    node_id = 0
    edges = []
    
    print(f"Reading {dot_file}...")
    
    with open(dot_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            
            # Match node definitions
            if '[' in line and 'label=' in line:
                parts = line.split('[', 1)
                node_num = parts[0].strip()
                if node_num and node_num not in node_map:
                    node_map[node_num] = node_id
                    node_id += 1
                    if node_id % 10000 == 0:
                        print(f"  Processed {node_id} nodes...")
            
            # Match edge definitions
            if '->' in line:
                parts = line.split('->', 1)
                src = parts[0].strip()
                dst_part = parts[1].split('[', 1)[0].strip()
                if src and dst_part:
                    edges.append((src, dst_part))
    
    print(f"\nFound {len(node_map)} nodes and {len(edges)} edges")
    
    # Write edge list
    print(f"Writing {edge_file}...")
    with open(edge_file, 'w', encoding='utf-8') as f:
        for i, (src, dst) in enumerate(edges):
            f.write(f"{node_map[src]} {node_map[dst]}\n")
            if (i + 1) % 100000 == 0:
                print(f"  Written {i + 1} edges...")
    
    # Write node mapping
    print(f"Writing {node_file}...")
    with open(node_file, 'w', encoding='utf-8') as f:
        for node_num, idx in sorted(node_map.items(), key=lambda x: x[1]):
            f.write(f"{idx}: {node_num}\n")
    
    print("\nDone!")
    print(f"  - {edge_file}")
    print(f"  - {node_file}")

if __name__ == "__main__":
    main()
