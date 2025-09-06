import os 
import sys
from ipdb import set_trace
sys.path.append("../compare_dataset")
from database import Database
import re
import hashlib
from elftools.elf.elffile import ELFFile
import json

db_fw = Database("firmware")

def get_dataset_from_60_fw():
    """
        get the squashfs paths coresponding to the brand
    """
    query = """  
            SELECT dataset_sample.brand, dataset_sample.image_id, dataset_sample.product_id, dataset_sample.rootfs, lua_interpreter_obfuscation_statistic.has_bytecode
            FROM dataset_sample
            LEFT JOIN lua_interpreter_obfuscation_statistic
            ON dataset_sample.image_id = lua_interpreter_obfuscation_statistic.image_id;    
            """
    db_params = (None, )
    table_image_info = db_fw.execute(query, db_params)  
    # set_trace()
    result = []
    # print(len(table_image_info))
    for image_info in table_image_info:  
        brand = image_info[0]
        image_id = image_info[1]
        product_id = image_info[2]
        rootfs_path = image_info[3]
        has_bytecode = image_info[4]
        result.append((brand, image_id, product_id, rootfs_path))
    return result

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

def get_dataset_dict():
    existing_dataset_path = "/home/nudt/lrh/first_work/compare_dataset/chosen_dataset_containing_lua"
    dataset_dict = dict()
    directory_list = os.listdir(existing_dataset_path)
    for entry in directory_list:
        dataset_dict[entry] = os.path.join(existing_dataset_path, entry)
    return dataset_dict

def get_IPC_info_for_13fw():
    base_path = "/home/nudt/lrh/first_work/compare_dataset/compare_result/existing_dataset/MyMethod"
    fw_info_dict = get_dataset_dict()
    # set_trace()
    collect_brand_list = list()
    all_fw_cmd_json = dict()
    for product, rootfs_path in fw_info_dict.items():
        # if "TOTOLink" in product:
        #     set_trace()
        IPC_report = os.path.join(base_path, product, "Lua_to_C/IPC")
        if os.path.exists(IPC_report):
            IPC_content = ""
            with open(IPC_report) as f:
                IPC_content = f.read()
            if IPC_content:
                cmd_json_list = list()
                cmd_list = extract_ipc_cmd(IPC_content)
                print(product)
                for cmd_tuple in cmd_list:
                    cmd_file = cmd_tuple[0]
                    full_cmd = cmd_tuple[1]
                    if cmd_file:
                        # set_trace()
                        file_sha256 = get_targe_file_sha256_in_fs(rootfs_path, cmd_file)
                        if file_sha256:
                            cmd_json = {
                                "bin": cmd_file,
                                "full_cmd": full_cmd,
                                "sha256": file_sha256
                            }
                            cmd_json_list.append(cmd_json)
                if cmd_json_list:
                    all_fw_cmd_json[product] = cmd_json_list

    with open("fw_cmd_json_13_fw", "w+") as f:
        json.dump(all_fw_cmd_json, f, indent=4)

def get_IPC_info_for_60fw():
    base_path = "/home/nudt/lrh/first_work/compare_dataset/compare_result/dataset_sample_60_fw/MyMethod/"
    fw_info_list = get_dataset_from_60_fw()
    # set_trace()
    collect_brand_list = list()
    all_fw_cmd_json = dict()
    for brand, image_id, product_id, rootfs_path in fw_info_list:
        collect_brand_list.append(brand)
        special_path = f"{image_id}_{product_id}"
        IPC_report = os.path.join(base_path, brand, special_path, "Lua_to_C/IPC")
        if os.path.exists(IPC_report):
            IPC_content = ""
            with open(IPC_report) as f:
                IPC_content = f.read()
            if IPC_content:
                cmd_json_list = list()
                cmd_list = extract_ipc_cmd(IPC_content)
                print(brand, special_path)
                for cmd_tuple in cmd_list:
                    cmd_file = cmd_tuple[0]
                    full_cmd = cmd_tuple[1]
                    if cmd_file:
                        # set_trace()
                        file_sha256 = get_targe_file_sha256_in_fs(rootfs_path, cmd_file)
                        if file_sha256:
                            cmd_json = {
                                "bin": cmd_file,
                                "full_cmd": full_cmd,
                                "sha256": file_sha256
                            }
                            cmd_json_list.append(cmd_json)
                if cmd_json_list:
                    all_fw_cmd_json[f"{brand}|{special_path}"] = cmd_json_list

    with open("fw_cmd_json", "w+") as f:
        json.dump(all_fw_cmd_json, f, indent=4)


if __name__ == "__main__":
    get_IPC_info_for_13fw()
