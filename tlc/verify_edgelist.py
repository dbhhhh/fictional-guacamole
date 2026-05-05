#!/usr/bin/env python3

def verify_edgelist(filename):
    print(f"Verifying {filename}...")
    print("=" * 60)
    
    node_ids = set()
    edge_count = 0
    errors = []
    
    with open(filename, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
                
            parts = line.split()
            if len(parts) != 2:
                errors.append(f"Line {line_num}: Invalid format - expected 2 numbers, got {len(parts)}")
                continue
                
            try:
                src = int(parts[0])
                dst = int(parts[1])
                node_ids.add(src)
                node_ids.add(dst)
                edge_count += 1
            except ValueError as e:
                errors.append(f"Line {line_num}: Invalid number - {e}")
    
    print(f"Total edges: {edge_count}")
    print(f"Total unique nodes: {len(node_ids)}")
    print(f"Minimum node ID: {min(node_ids)}")
    print(f"Maximum node ID: {max(node_ids)}")
    
    expected_nodes = 512000  # 80^3
    if len(node_ids) == expected_nodes:
        print(f"✓ Node count matches expected: {expected_nodes}")
    else:
        print(f"✗ Node count mismatch: got {len(node_ids)}, expected {expected_nodes}")
    
    if errors:
        print("\nErrors found:")
        for error in errors[:10]:
            print(f"  {error}")
        if len(errors) > 10:
            print(f"  ... and {len(errors) - 10} more")
    else:
        print("\n✓ No format errors found")
    
    print("\nSample edges (first 5):")
    with open(filename, 'r', encoding='utf-8') as f:
        for i, line in enumerate(f):
            if i >= 5:
                break
            print(f"  {line.strip()}")
    
    print("\n" + "=" * 60)
    return len(errors) == 0

if __name__ == "__main__":
    success = verify_edgelist("edge_list.txt")
    exit(0 if success else 1)
