import os
import sys
import json
from ipdb import set_trace
from collections import defaultdict



def load_json_from_file(json_path):
    IPC_list = None
    if os.path.exists(json_path):
        with open(json_path) as f:
            IPC_list = json.load(f)
    return IPC_list

def search_argv_vul_in_result(result_json):
    # cmdi_json["closures"]
    arhv_vul_num = 0
    for vul_info in  result_json["closures"]:
        # set_trace()
        input_dict = vul_info["inputs"]
        if input_dict["likely"] or input_dict["possibly"]:
            print(input_dict["likely"], input_dict["possibly"])
            # set_trace()
        if "ARGV" in input_dict["likely"] or "ARGV" in input_dict["possibly"]:
            arhv_vul_num += 1
    return arhv_vul_num

num = 0

def get_argv_vul_in_result_dir(bin_result_dir):
    argv_result_list = list()
    global num
    # print(num)
    num += 1
    # cmdi_results.json, overflow_results.json
    cmdi_results = os.path.join(bin_result_dir, "cmdi_results.json")
    cmdi_json = load_json_from_file(cmdi_results)
    cmdi_vul_num = search_argv_vul_in_result(cmdi_json)

    if cmdi_vul_num:
        argv_result_list.append((cmdi_results, cmdi_vul_num))

    overflow_results = os.path.join(bin_result_dir, "overflow_results.json")
    overflow_json = load_json_from_file(overflow_results)
    overflow_vul_num = search_argv_vul_in_result(overflow_json)
    if overflow_vul_num:
        argv_result_list.append((overflow_results, overflow_vul_num))
    
    return argv_result_list


if __name__ == "__main__":
    scan_bin_list = list()
    json_path = "fw_cmd_json"
    mango_result_path = "/data/lrh/first_work/mango_dfa_result2/73fw/sample_60_fw"
    IPC_dict = load_json_from_file(json_path)
    founded_vul = 0
    record = defaultdict(list)
    argv_record = defaultdict(list)
    for fw_info, cmd_list in IPC_dict.items():
        brand, image_signature = fw_info.split("|")
        # print(brand, image_signature)
        for cmd_dict in cmd_list:
            # {'bin': 'puDataStr', 'full_cmd': "puDataStr set installEvent TOP 'TOP'", 'sha256': '275e58af0d958c6dac5199d9a0abdf4ae877fa77f16c5820e06a0405939ddaee'}
            bin = cmd_dict["bin"]
            record[brand].append(bin)
            # print(bin)
            bin_record = f"{fw_info}|{bin}"
            if bin_record in scan_bin_list:
                continue
            else:
                scan_bin_list.append(bin_record)
            full_cmd = cmd_dict["full_cmd"]
            sha256 = cmd_dict["sha256"]
            bin_result_dir = os.path.join(mango_result_path, brand, image_signature, sha256)
            if os.path.exists(bin_result_dir):
                print(bin)
                argv_result_list = get_argv_vul_in_result_dir(bin_result_dir)
                if argv_result_list:
                    argv_record[fw_info].extend(argv_result_list)
        
        if argv_record[fw_info]:
            print(argv_record[fw_info])
            set_trace()
    
    print("*"*20)
    for brand, bin_list in record.items():
        print(brand)
        print(set(bin_list))
        print("")