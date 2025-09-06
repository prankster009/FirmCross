#!/usr/bin/env python3

import os
import json
import re
from ipdb import set_trace
import subprocess
import shutil
import shlex
import sys
import string
import random

def execute_cmd(cmd):
    # set_trace()
    command = shlex.split(cmd)
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)  
    return result.returncode, result.stderr, result.stdout

def get_lib_name(lua_table_path, func_name):
    with open(lua_table_path) as f:
        table_content = json.load(f)
        for lib_name, function_lists in table_content.items():
            for func_dict in function_lists:
                if func_dict["name"] == func_name:
                    return lib_name
    return None

def get_lib_path(fw_path, lib_name):
    for dirpath, _, filenames in os.walk(fw_path):
        for filename in filenames:
            if filename == lib_name:
                lib_path = os.path.join(dirpath, filename)
                return lib_path
    return None

def get_target_libso_path(lua_table_path, lua_table_sink_path, fw_path):
    report_info = ""
    with open(lua_table_sink_path) as f:
        report_info = f.read()
    pattern = re.compile(
        r'Vulnerability (\d+):.*?'
        r'Source.*?File: (.*?), Function: (.*?)\s+pc: (-?\d+), trigger: "(.*?)".*?'
        r'Sink.*?File: (.*?), Function: (.*?)\s+pc: (-?\d+), trigger: "(.*?)", param idx: (\d+).*?',
        re.DOTALL
    )
    # set_trace()
    for match in re.finditer(pattern, report_info):
        C_function_name = match.group(9)
        lib_name = get_lib_name(lua_table_path, func_name)
        abs_lib_path = get_lib_path(fw_path, lib_name)
        return abs_lib_path

def scan_Lua2C_API_vul(Lua_table_path, Lua_table_sink_dir, fw_path, Lua2C_API_vul_result_dir):
    if not os.path.exists(Lua_table_sink_dir):
        return
    for table_sink_report in os.listdir(Lua_table_sink_dir):
        abs_table_sink_report = os.path.join(Lua_table_sink_dir, table_sink_report)
        lib_path = get_target_libso_path(Lua_table_path, abs_table_sink_report, fw_path)
        if lib_path:
            result_path_dir = os.path.join(Lua2C_API_vul_result_dir,os.path.basename(lib_path))
            cmd = f"mango '{lib_path}' --results {result_path_dir} --lua2c-api-path {abs_table_sink_report}"
            returncode, return_stderr, output = execute_cmd(cmd)
            if returncode != 0:
                # error_msg = f"{basename} error, error msg:{return_stderr}"
                error_msg = f"{basename} error, error_msg: {return_stderr}"
                # print(error_msg)
                continue
            

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python script.py Lua_table_path Lua_table_sink_dir fw_path Lua2C_API_vul_result_dir")
        sys.exit(1)

    Lua_table_path = sys.argv[1]
    Lua_table_sink_dir = sys.argv[2]
    fw_path = sys.argv[3]
    Lua2C_API_vul_result_dir = sys.argv[4]

    scan_Lua2C_API_vul(Lua_table_path, Lua_table_sink_dir, fw_path, Lua2C_API_vul_result_dir)