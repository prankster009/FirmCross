#!/usr/bin/env python3
import sys
from utils.logger import init_logger_path
import json
import os
from ipdb import set_trace
import hashlib
import time
import random
import string

# parse C2Lua_API_result and scan related lua file
C2Lua_API_result = "/home/iot_2204/operation-mango-public/package/tests/my_test/C2Lua_API/results/c2lua_api_path"
squashfs_root = "/home/iot_2204/lua_analysis/Luabyte_Taint_large_test/test_case/test8"
API_json = list()

# the init_logger_path must execute before import Whole_Module
output_dir = "/home/iot_2204/operation-mango-public/package/tests/my_test/C2Lua_API/results"
init_logger_path(output_dir)

if os.path.exists(C2Lua_API_result):
    with open(C2Lua_API_result, 'r', encoding='utf-8') as f:
        API_json = json.load(f) 

def is_lua_bytecode(filename):
    # TODO: fix
    with open(filename, 'rb') as f:
        header = f.read(4)  # Read the first 4 bytes
        
        # Check if it matches Lua's bytecode magic number for Lua 5.1, 5.2, 5.3
        if header == b'\x1b\x4c\x75\x61':  # Lua magic number for bytecode
            return True
        
        # If no magic number is found, assume it is source code
        return False

def search_target_file(squashfs_root, lua_name):
    for dirpath, _, filenames in os.walk(squashfs_root):
        for filename in filenames:
            if filename == lua_name or filename == f"{lua_name}c":
                abs_lua_file = os.path.join(dirpath, filename)
                if is_lua_bytecode(abs_lua_file):
                    return abs_lua_file
    return None

def get_random_filename():

    timestamp = int(time.time())

    random_str = ''.join(random.choices(
        string.ascii_letters + string.digits, 
        k=10
    ))
    
    # 组合时间戳和随机字符串
    data_to_hash = f"{timestamp}{random_str}".encode('utf-8')
    
    # 计算哈希值 (使用 SHA-256)
    hash_object = hashlib.sha256(data_to_hash)
    hex_dig = hash_object.hexdigest()[:16*2]  # 转换为16进制字符串
    
    return hex_dig

def get_sinks_definition():
    sinks_definition_path = "./vulnerability_definitions/definition_sink_template.pyt"
    with open(sinks_definition_path, 'r', encoding='utf-8') as f:
        sinks_definition = json.load(f) 
    return sinks_definition


from analysis.module import Whole_Module


for API_record in API_json:
    # set_trace()
    # print(API_record)
    # {'file': 'event_report.lua', 'func': 'reset_stat_params_config', 'idxs': [0]}
    lua_file = API_record["file"]
    function = API_record["func"]
    tainted_idxs = API_record["idxs"]
    abs_luac_file = search_target_file(squashfs_root, lua_file)
    if not abs_luac_file:
        continue
    random_pyt_file = f"/tmp/{get_random_filename()}.pyt"
    sink_definitions = get_sinks_definition()
    source_sink_definitions = dict()
    source_instance = {
        function: {
            "type": "param",
            "idx": tainted_idxs
        }

    }
    source_sink_definitions["sources"] = source_instance
    source_sink_definitions.update(sink_definitions)
    print(abs_luac_file, random_pyt_file)
    with open(random_pyt_file, 'w', encoding='utf-8') as f:
        json.dump(source_sink_definitions, f, indent=4)

    whole_module = Whole_Module(
                                fw_path=abs_luac_file, 
                                output_dir=output_dir, 
                                resolve_source=True, 
                                is_vul_discover=True, 
                                debug = False,
                                sources_and_sinks_definition = random_pyt_file
                            )
    
    os.system(f"rm {random_pyt_file}")
    






