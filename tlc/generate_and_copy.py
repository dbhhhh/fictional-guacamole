#!/usr/bin/env python3

import os
import subprocess
import shutil
import datetime
import glob
import sys
from specifications import get_all_specifications, list_specifications, get_specification

MAX_FILE_SIZE_MB = 1500
MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024

def run_tlc_for_spec(spec_name, tla_file, cfg_file):
    cleanup_old_files()

    spec_basename = os.path.basename(tla_file)
    cfg_basename = os.path.basename(cfg_file)

    if os.path.exists(spec_basename):
        os.remove(spec_basename)
    shutil.copy(tla_file, spec_basename)

    if os.path.exists(cfg_basename):
        os.remove(cfg_basename)
    shutil.copy(cfg_file, cfg_basename)

    module_name = os.path.splitext(spec_basename)[0]
    module_cfg = f"{module_name}.cfg"
    if module_cfg != cfg_basename and os.path.exists(module_cfg):
        os.remove(module_cfg)
    shutil.copy(cfg_file, module_cfg)

    spec_dir = os.path.dirname(tla_file)
    for dep_file in os.listdir(spec_dir):
        dep_path = os.path.join(spec_dir, dep_file)
        if dep_file.endswith('.tla') and dep_file != spec_basename:
            if os.path.exists(dep_file):
                os.remove(dep_file)
            shutil.copy(dep_path, dep_file)

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    dot_file = f"state_graph_{spec_name}_{timestamp}.dot"

    cmd = f'java -jar tla2tools.jar -dump dot {dot_file} {module_name}'
    print(f"  执行: {cmd}")

    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=3600)
        print(f"  TLC执行完成，返回码: {result.returncode}")
    except subprocess.TimeoutExpired:
        print(f"  警告: TLC执行超时")
        return None
    except Exception as e:
        print(f"  警告: TLC执行异常: {str(e)}")
        return None

    if os.path.exists(dot_file):
        file_size = os.path.getsize(dot_file)
        print(f"  DOT文件大小: {file_size / 1024 / 1024:.2f} MB")
        if file_size > MAX_FILE_SIZE_BYTES:
            print(f"  警告: DOT文件过大 ({file_size / 1024 / 1024:.2f} MB)，超过限制 {MAX_FILE_SIZE_MB} MB")
            os.remove(dot_file)
            return None
        elif file_size > 100:
            print(f"  DOT文件生成成功")
            return dot_file
        else:
            print(f"  警告: DOT文件内容为空")
    else:
        print(f"  警告: DOT文件生成失败")
        if result.stdout:
            print(f"  标准输出: {result.stdout[:200]}")
        if result.stderr:
            print(f"  错误输出: {result.stderr[:200]}")
    return None

def cleanup_old_files():
    for dot_file in glob.glob("state_graph_*.dot"):
        try:
            os.remove(dot_file)
        except:
            pass

    for py_file in glob.glob("*.py"):
        pass

    for cfg_file in glob.glob("*.cfg"):
        try:
            os.remove(cfg_file)
        except:
            pass

    if os.path.exists("states"):
        try:
            shutil.rmtree("states")
        except:
            pass

def convert_to_edgelist(dot_file, spec_name):
    edge_file = f"edge_list_{spec_name}.txt"

    cmd = f"python fast_convert.py {dot_file} {edge_file}"
    print(f"  执行: {cmd}")

    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

    if os.path.exists(edge_file):
        file_size = os.path.getsize(edge_file)
        if file_size > MAX_FILE_SIZE_BYTES:
            print(f"  警告: 边列表文件过大 ({file_size / 1024 / 1024:.2f} MB)，超过限制 {MAX_FILE_SIZE_MB} MB")
            os.remove(edge_file)
            return None
        elif file_size > 0:
            return edge_file
        else:
            print(f"  警告: 边列表文件内容为空")
    else:
        print(f"  警告: 边列表文件生成失败")
        if result.stderr:
            print(f"  错误输出: {result.stderr[:200]}")
    return None

def copy_to_test_folder(edge_file):
    test_folder = r"d:\Desktop\result\test"
    if not os.path.exists(test_folder):
        os.makedirs(test_folder)

    dest_path = os.path.join(test_folder, os.path.basename(edge_file))
    if os.path.exists(dest_path):
        os.remove(dest_path)
    shutil.copy(edge_file, dest_path)
    return dest_path

def process_specification(spec):
    print(f"\n{'='*80}")
    print(f"处理规约: {spec.name}")
    print(f"{'='*80}")
    print(f"处理规约: {spec.name}")
    print(f"  TLA文件: {spec.tla_file}")
    print(f"  CFG文件: {spec.cfg_file}")

    print("  步骤1: 运行TLC...")
    dot_file = run_tlc_for_spec(spec.name, spec.tla_file, spec.cfg_file)

    if dot_file:
        print("  步骤2: 转换为边列表...")
        edge_file = convert_to_edgelist(dot_file, spec.name)

        if edge_file:
            print("  步骤3: 复制到test文件夹...")
            dest_path = copy_to_test_folder(edge_file)
            print(f"  ✓ 完成: {dest_path}")
            return True
    return False

def main():
    print(f"\n{'='*80}")
    print("批量生成边列表")
    print(f"{'='*80}")

    specs = get_all_specifications()

    if len(sys.argv) > 1:
        if sys.argv[1] == "--all":
            list_specifications()
            for spec_name, spec in specs.items():
                process_specification(spec)
        else:
            spec_name = sys.argv[1]
            spec = get_specification(spec_name)
            if spec:
                process_specification(spec)
            else:
                list_specifications()
                print(f"未找到规约: {spec_name}")
    else:
        list_specifications()
        spec_name = input("请输入要处理的规约名称: ")
        spec = get_specification(spec_name)
        if spec:
            process_specification(spec)
        else:
            print(f"未找到规约: {spec_name}")

if __name__ == "__main__":
    main()
