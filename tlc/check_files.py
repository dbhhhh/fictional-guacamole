#!/usr/bin/env python3

def check_file(filename):
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            print(f"{filename}: {len(lines)} lines")
            if len(lines) > 0:
                print(f"  First 3 lines:")
                for line in lines[:3]:
                    print(f"    {line.strip()}")
                if len(lines) > 3:
                    print(f"  Last 3 lines:")
                    for line in lines[-3:]:
                        print(f"    {line.strip()}")
    except Exception as e:
        print(f"Error reading {filename}: {e}")

if __name__ == "__main__":
    print("Checking files...\n")
    check_file("edge_list.txt")
    print()
    check_file("edge_list_nodes.txt")
    print()
    check_file("state_graph.dot")
