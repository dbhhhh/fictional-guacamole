#!/usr/bin/env python3
"""
规约配置模块
从本地examples文件夹加载规约配置
"""

import os
import glob
import json

class Specification:
    def __init__(self, name, tla_file, cfg_file, description=None):
        self.name = name
        self.tla_file = tla_file
        self.cfg_file = cfg_file
        self.description = description or f"{name}规约"

    def __str__(self):
        return f"{self.name}: {self.description}"

def scan_examples_folder():
    """从本地examples文件夹加载六个目标规约"""
    base_dir = os.path.dirname(os.path.abspath(__file__))
    examples_dir = os.path.join(base_dir, 'examples')

    if not os.path.exists(examples_dir):
        return {}

    specs = {}
    
    # 定义六个目标规约：小型2个、中型2个、大型2个
    target_specs = {
        # 小型规约
        'DieHard': {
            'dir': 'DieHard',
            'tla': 'DieHard.tla',
            'cfg': 'DieHard.cfg',
            'desc': 'Die Hard - 两个水罐问题 (小型)'
        },
        'MissionariesAndCannibals': {
            'dir': 'MissionariesAndCannibals',
            'tla': 'MissionariesAndCannibals.tla',
            'cfg': 'MissionariesAndCannibals.cfg',
            'desc': 'Missionaries and Cannibals - 传教士与食人族问题 (小型)'
        },
        # 中型规约
        'EWD840': {
            'dir': 'ewd840',
            'tla': 'EWD840.tla',
            'cfg': 'EWD840.cfg',
            'desc': 'EWD840 - 环形终止检测算法 (中型)'
        },
        'ReadersWriters': {
            'dir': 'ReadersWriters',
            'tla': 'MC.tla',
            'cfg': 'MC.cfg',
            'desc': 'ReadersWriters - 读者写者问题 (中型)'
        },
        # 大型规约
        'MultiPaxos-SMR': {
            'dir': 'MultiPaxos-SMR',
            'tla': 'MultiPaxos_MC.tla',
            'cfg': 'MultiPaxos_MC_small.cfg',
            'desc': 'MultiPaxos-SMR - SMR风格MultiPaxos (大型)'
        },
        'NanoBlockchain': {
            'dir': 'NanoBlockchain',
            'tla': 'MCNano.tla',
            'cfg': 'MCNano.cfg',
            'desc': 'NanoBlockchain - 区块链模型 (大型)'
        }
    }

    for spec_name, spec_info in target_specs.items():
        spec_dir = os.path.join(examples_dir, spec_info['dir'])
        if os.path.exists(spec_dir):
            tla_file = os.path.join(spec_dir, spec_info['tla'])
            cfg_file = os.path.join(spec_dir, spec_info['cfg'])
            if os.path.exists(tla_file) and os.path.exists(cfg_file):
                specs[spec_name.lower()] = Specification(
                    name=spec_name,
                    tla_file=tla_file,
                    cfg_file=cfg_file,
                    description=spec_info['desc']
                )
            else:
                print(f"警告: {spec_name} 的配置文件不存在")

    return specs

SPECIFICATIONS = scan_examples_folder()

def list_specifications():
    """列出所有可用的规约"""
    print("\n可用的规约列表：")
    print("-" * 80)
    for key, spec in sorted(SPECIFICATIONS.items()):
        print(f"  {spec.name:30s} - {spec.description}")
    print("-" * 80)

def get_specification(name):
    """获取指定名称的规约"""
    return SPECIFICATIONS.get(name.lower())

def get_all_specifications():
    """获取所有规约"""
    return SPECIFICATIONS

def select_specification():
    """交互式选择规约"""
    list_specifications()
    while True:
        choice = input("\n请选择规约名称: ").strip()
        spec = get_specification(choice)
        if spec:
            return spec
        print("无效的规约名称，请重新输入。")

def select_all_specifications():
    """选择所有规约"""
    list_specifications()
    choice = input("\n是否处理所有规约? (y/n): ").strip().lower()
    return choice == 'y'
