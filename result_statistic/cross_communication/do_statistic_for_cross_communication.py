import os 
import sys
from ipdb import set_trace
import re
import hashlib
from elftools.elf.elffile import ELFFile
import json

def extract_ipc_cmd(content):
    # content = """
    # cmd_bin: puDataStr           , full_cmd: puDataStr set installEvent TOP 'TOP'
    # cmd_bin: puDataStr           , full_cmd: puDataStr set installEvent TOP 'TOP'
    # cmd_bin:                     , full_cmd: TOP -- get_local_ip
    # cmd_bin:                     , full_cmd: TOP -- get_local_ip
    # cmd_bin:                     , full_cmd: TOP -- get_local_ip
    # cmd_bin:                     , full_cmd: TOP -- get_local_ip
    # """
    pattern = r'cmd_bin:\s*(\S*)\s*,\s*full_cmd:\s*(\S.*)'
    matches = re.findall(pattern, content)
    result = []
    for cmd_bin, full_cmd in matches:
        parsed_cmd_bin = cmd_bin.strip() if cmd_bin else None
        if parsed_cmd_bin:
            parsed_cmd_bin = parsed_cmd_bin.split("/")[-1]
        parsed_full_cmd = full_cmd.strip() if full_cmd else None
        result.append((parsed_cmd_bin, parsed_full_cmd))
    return result    

def extract_ipc_cmd_bak(content):
    # content = """
    # cmd_bin: puDataStr           , full_cmd: puDataStr set installEvent TOP 'TOP'
    # cmd_bin: puDataStr           , full_cmd: puDataStr set installEvent TOP 'TOP'
    # cmd_bin:                     , full_cmd: TOP -- get_local_ip
    # cmd_bin:                     , full_cmd: TOP -- get_local_ip
    # cmd_bin:                     , full_cmd: TOP -- get_local_ip
    # cmd_bin:                     , full_cmd: TOP -- get_local_ip
    # """
    pattern = r'cmd_bin:\s*(\S*)\s*,\s*full_cmd:\s*(\S.*)'
    matches = re.findall(pattern, content)
    result = []
    for cmd_bin, full_cmd in matches:
        parsed_cmd_bin = cmd_bin.strip() if cmd_bin else None
        if parsed_cmd_bin:
            parsed_cmd_bin = parsed_cmd_bin.split("/")[-1]
        parsed_full_cmd = full_cmd.strip() if full_cmd else None
        if (parsed_cmd_bin, parsed_full_cmd) not in result:
            result.append((parsed_cmd_bin, parsed_full_cmd))
    return result    

def is_elf_file(file_path):
    try:
        with open(file_path, 'rb') as file:
            ELFFile(file)
            return True
    except Exception:
        return False

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

def get_targe_file_sha256_in_fs(fs_path, target_file):
    if os.path.exists(fs_path):
        for root, dirs, files in os.walk(fs_path):
            for file in files:
                if file == target_file:
                    file_path = os.path.join(root, file)
                    # 处理符号链接
                    if os.path.islink(file_path):
                        file_path = os.path.realpath(file_path)
                        file_path = os.path.join(fs_path, file_path)
                    
                    if os.path.exists(file_path) and is_elf_file(file_path):
                        sha256 = calculate_sha256(file_path)
                        return sha256

    return None

def get_targe_file_sha256_in_fs_bak(fs_path, target_file):
    target_dir = ["bin", "usr", "sbin"]
    for candidate_dir in target_dir:
        search_path = os.path.join(fs_path, candidate_dir)
        if os.path.exists(search_path):
            for root, dirs, files in os.walk(search_path):
                for file in files:
                    if file == target_file:
                        file_path = os.path.join(root, file)
                        # 处理符号链接
                        if os.path.islink(file_path):
                            file_path = os.path.realpath(file_path)
                            file_path = os.path.join(fs_path, file_path)
                        
                        if os.path.exists(file_path) and is_elf_file(file_path):
                            sha256 = calculate_sha256(file_path)
                            return sha256

    return None

def load_json_from_file(json_path):
    IPC_list = None
    if os.path.exists(json_path):
        with open(json_path) as f:
            IPC_list = json.load(f)
    return IPC_list

def get_IPC_times(IPC_path, fs_path):
    IPC_communication_times = 0
    if os.path.exists(IPC_path):
        IPC_content = ""
        with open(IPC_path) as f:
            IPC_content = f.read()
        if IPC_content:
            cmd_json_list = list()
            cmd_list = extract_ipc_cmd(IPC_content)
            for cmd_tuple in cmd_list:
                cmd_file = cmd_tuple[0]
                full_cmd = cmd_tuple[1]
                if cmd_file:
                    file_sha256 = get_targe_file_sha256_in_fs(fs_path, cmd_file)
                    if file_sha256:
                        IPC_communication_times += 1
    return IPC_communication_times

def get_API_times(sink_info_path):
    API_communication_times = 0
    if os.path.exists(sink_info_path):
        sinks = list()
        with open(sink_info_path) as f:
            sinks = json.load(f)
        for sink in sinks:
            if sink["type"] == "Sink_Lua_Table_Func":
                API_communication_times += 1

    return API_communication_times

def get_API_times2(lua_table_path):
    API_communication_times = 0
    if os.path.exists(lua_table_path):
        lua_table = list()
        with open(lua_table_path) as f:
            lua_table = json.load(f)
        for lib, funcList in lua_table.items():
            API_communication_times += len(funcList)

    return API_communication_times
    
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python lua_result_path fw_path")
        sys.exit(1)

    lua_result = sys.argv[1]
    fs_path = sys.argv[2]
    
    IPC_path = os.path.join(lua_result, "Lua_to_C/IPC")
    sink_info_path = os.path.join(lua_result,"sink_identify/sink")

    IPC_times = get_IPC_times(IPC_path, fs_path)
    API_times = get_API_times(sink_info_path)

    print(IPC_times, API_times)
    # python do_statistic_for_cross_communication.py /data/lrh/first_work/firmcross_ae/minimize_testcase/result_one_xiaomi_fw/single_lua /data/lrh/first_work/firmcross_ae/minimize_testcase/dataset_one_xiaomi_fw/xiaomi/2066_2768/squashfs-root/