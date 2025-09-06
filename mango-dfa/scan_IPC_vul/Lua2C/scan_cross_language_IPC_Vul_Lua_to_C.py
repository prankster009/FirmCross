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
        if (parsed_cmd_bin, parsed_full_cmd) not in result:
            result.append((parsed_cmd_bin, parsed_full_cmd))
    return result    

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

def is_elf_file(file_path):
    try:
        with open(file_path, 'rb') as file:
            ELFFile(file)
            return True
    except Exception:
        return False

def get_targe_file_sha256_in_fs(fs_path, target_file):
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
                            # result.append((file_path, md5))
                        # break
    return None

def search_argv_vul_in_result(result_json):
    # cmdi_json["closures"]
    argv_vul_num = 0
    if not result_json:
        return
    for vul_info in  result_json["closures"]:
        # set_trace()
        input_dict = vul_info["inputs"]
        # if input_dict["likely"] or input_dict["possibly"]:
        #     print(input_dict["likely"], input_dict["possibly"])
            # set_trace()
        if "ARGV" in input_dict["likely"] or "ARGV" in input_dict["possibly"]:
            rank = vul_info["rank"]
            if rank >= 0.4:
                argv_vul_num += 1
    return argv_vul_num

def load_json_from_file(json_path):
    IPC_list = None
    if os.path.exists(json_path):
        with open(json_path) as f:
            IPC_list = json.load(f)
    return IPC_list

def get_argv_vul_in_result_dir(bin_result_dir):
    argv_result_list = list()
    argv_vul_num = 0
    # cmdi_results.json, overflow_results.json
    cmdi_results = os.path.join(bin_result_dir, "cmdi_results.json")
    cmdi_json = load_json_from_file(cmdi_results)
    cmdi_vul_num = search_argv_vul_in_result(cmdi_json)

    if cmdi_vul_num:
        argv_result_list.append((cmdi_results, cmdi_vul_num))
        argv_vul_num += cmdi_vul_num

    overflow_results = os.path.join(bin_result_dir, "overflow_results.json")
    overflow_json = load_json_from_file(overflow_results)
    overflow_vul_num = search_argv_vul_in_result(overflow_json)
    if overflow_vul_num:
        argv_result_list.append((overflow_results, overflow_vul_num))
        argv_vul_num += overflow_vul_num

    return argv_vul_num, argv_result_list

def scan_Lua2C_IPC_vul_according_to_Lua_IPC_result(IPC_path, fs_path, C_report_path, argv_vul_dir):
    if os.path.exists(IPC_path):
        IPC_content = ""
        with open(IPC_path) as f:
            IPC_content = f.read()
        cmd_json_list = list()
        if IPC_content:
            cmd_list = extract_ipc_cmd(IPC_content)
            for cmd_tuple in cmd_list:
                cmd_file = cmd_tuple[0]
                full_cmd = cmd_tuple[1]
                if cmd_file:
                    file_sha256 = get_targe_file_sha256_in_fs(fs_path, cmd_file)
                    if file_sha256:
                        cmd_json = {
                            "bin": cmd_file,
                            "full_cmd": full_cmd,
                            "sha256": file_sha256
                        }
                        bin_result_dir = os.path.join(C_report_path, file_sha256)
                        if os.path.exists(bin_result_dir):
                            # if cmd_file == "portscan":
                            #     set_trace()
                            cross_languge_num, argv_result_list = get_argv_vul_in_result_dir(bin_result_dir)
                            cmd_json["argv_num"] = cross_languge_num
                            cmd_json["argv_vul"] = argv_result_list
                        cmd_json_list.append(cmd_json)
        if not os.path.exists(argv_vul_dir):
            os.makedirs(argv_vul_dir, exist_ok=True)
        result_path = os.path.join(argv_vul_dir, "Lua2C_IPC_Vul")
        with open(result_path, "w") as f:
            json.dump(cmd_json_list, f, indent=4)


if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python script.py C_report_path Lua_report_path Cross_language_IPC_Vul_dir")
        sys.exit(1)

    IPC_path = sys.argv[1]
    fs_path = sys.argv[2]
    C_report_path = sys.argv[3]
    argv_vul_dir = sys.argv[4]


    real_fs_path = None
    if os.path.exists(fs_path):
        for root, dirs, files in os.walk(fs_path):
            if root.endswith("squashfs-root"):
                real_fs_path = os.path.abspath(root)

    real_c_report_path = None
    if os.path.exists(C_report_path):
        for root, dirs, files in os.walk(C_report_path):
            for file in files:
                if file == "keywords.json" or file == "vendor.json":
                    real_c_report_path = os.path.abspath(root)
                    

    if not real_c_report_path or not real_fs_path:
        sys.exit(0)

    scan_Lua2C_IPC_vul_according_to_Lua_IPC_result(IPC_path, real_fs_path, real_c_report_path, argv_vul_dir)
