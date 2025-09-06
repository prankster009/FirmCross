import os 
import sys
from ipdb import set_trace
import re
import hashlib
from elftools.elf.elffile import ELFFile
import json

def calculate_sha256(file_path):
    sha256 = hashlib.sha256()
    # set_trace()
    try:
        with open(file_path, 'rb') as file:
            for chunk in iter(lambda: file.read(4096), b""):
                sha256.update(chunk)
        hash_value = sha256.hexdigest()
        return hash_value
    except Exception as e:
        print(e)
        return

def check_string_in_program(file_path, target_string):
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as file:
        content = file.read()
        return target_string in content


def is_elf_file(file_path):
    try:
        with open(file_path, 'rb') as file:
            ELFFile(file)
            return True
    except Exception:
        return False

def get_bin_list_contain_C2Lua_API(fs_path):
    candidate_bin_list = list()
    if os.path.exists(fs_path):
        for root, dirs, files in os.walk(fs_path):
            for file in files:
                file_path = os.path.join(root, file)
                # 处理符号链接
                if os.path.islink(file_path):
                    file_path = os.path.realpath(file_path)
                    file_path = os.path.join(fs_path, file_path)
                if ".so" in file_path:
                    continue
                if os.path.exists(file_path) and is_elf_file(file_path):
                    if check_string_in_program(file_path, "luaL_loadfile") and \
                        check_string_in_program(file_path, "lua_getglobal") and \
                            check_string_in_program(file_path, "lua_pushstring"):
                        candidate_bin_list.append(file_path)
    return candidate_bin_list

def detect_C2Lua_api_info(fs_path, result_dir):
    if not os.path.exists(result_dir):
        os.makedirs(result_dir)
    candidate_bin_list = get_bin_list_contain_C2Lua_API(fs_path)
    for bin_file in candidate_bin_list:
        file_hash = calculate_sha256(file_path)
        C2Lua_API_info_path = os.path.join(result_dir, file_hash)
        cmd = f"mango {bin_file} --category c2lua_api --c2lua-api-path {C2Lua_API_info_path}"
        returncode, return_stderr, output = execute_cmd(cmd)
        if returncode != 0:
            continue
    
        """
        API result is as bellow
        [
            {
                "file": "event_report.lua",
                "func": "reset_stat_params_config",
                "idxs": [
                    0
                ]
            }
        ]
        """

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py fs_path C2Lua_API_result_dir")
        sys.exit(1)

    fs_path = sys.argv[1]
    C2Lua_API_result_dir = sys.argv[2]
    detect_C2Lua_api_info(fs_path, C2Lua_API_result_dir)
