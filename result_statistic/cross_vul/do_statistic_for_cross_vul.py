import os 
import sys
from ipdb import set_trace
import re
import hashlib
import json

def get_num_IPC_Lua2C_vul(Lua2C_IPC_vul_path):
    IPC_vul_num = 0
    if os.path.exists(Lua2C_IPC_vul_path):
        IPC_content = list()
        with open(Lua2C_IPC_vul_path) as f:
            IPC_content = json.load(f)
        for IPC in IPC_content:
            if "argv_num" in IPC:
                IPC_vul_num += IPC["argv_num"]
    return IPC_vul_num

def get_num_IPC_C2Lua_vul(C2Lua_IPC_vul_path):
    IPC_vul_num = 0
    if os.path.exists(C2Lua_IPC_vul_path):
        IPC_content = list()
        with open(C2Lua_IPC_vul_path) as f:
            IPC_content = json.load(f)
        IPC_vul_num += len(IPC_content)
    return IPC_vul_num

def get_num_API_Lua2C_vul(Lua2C_API_vul_path):
    API_vul_num = 0
    pattern = re.compile(r'^[7-9]', re.IGNORECASE)
    for root, _, files in os.walk(Lua2C_API_vul_path):
        for file in files:
            if pattern.match(file):
                API_vul_num += 1
    return API_vul_num

def get_num_API_C2Lua_vul(C2Lua_API_vul_path):
    API_vul_num = 0
    if os.path.exists(C2Lua_API_vul_path):
        for dirpath, _, filenames in os.walk(C2Lua_API_vul_path):
            for filename in filenames:
                if filename == "summary":
                    summary_content = ""
                    summary_path = os.path.join(dirpath, filename)
                    with open(summary_path) as f:
                        summary_content = f.read()
                    try:
                        API_vul_num += int(summary_content.split()[0])
                    except:
                        pass
    return API_vul_num

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py cross_vul_result_path")
        sys.exit(1)

    cross_vul_result_path = sys.argv[1]

    Lua2C_IPC_vul_path = os.path.join(cross_vul_result_path, "IPC_vul/Lua2C_IPC_Vul")
    IPC_Lua2C_num = get_num_IPC_Lua2C_vul(Lua2C_IPC_vul_path)
    print(f"IPC_Lua2C_num: {IPC_Lua2C_num}")

    C2Lua_IPC_vul_path = os.path.join(cross_vul_result_path, "IPC_vul/C2Lua_IPC_Vul")
    IPC_C2Lua_num = get_num_IPC_C2Lua_vul(C2Lua_IPC_vul_path)
    print(f"IPC_C2Lua_num: {IPC_C2Lua_num}")

    C2Lua_API_vul_path = os.path.join(cross_vul_result_path, "API_vul/C2Lua/API_Vul")
    API_C2Lua_num = get_num_API_C2Lua_vul(C2Lua_API_vul_path)
    print(f"API_C2Lua_num: {API_C2Lua_num}")

    Lua2C_API_vul_path = os.path.join(cross_vul_result_path, "API_vul/Lua2C")
    API_Lua2C_num = get_num_API_Lua2C_vul(Lua2C_API_vul_path)
    print(f"API_Lua2C_num: {API_Lua2C_num}")

    # python do_statistic_for_cross_vul.py /data/lrh/first_work/firmcross_ae/minimize_testcase/result_one_xiaomi_fw/cross_vul

    
