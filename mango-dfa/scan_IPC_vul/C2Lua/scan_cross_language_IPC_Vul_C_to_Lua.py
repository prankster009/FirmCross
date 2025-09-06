from ipdb import set_trace
import re
import os
import sys

def extract_quoted_content(text):
    """从文本中提取双引号内的内容"""
    # 使用正则表达式匹配双引号内的内容，忽略转义字符
    pattern = r'"([^"\\]*(?:\\.[^"\\]*)*)"'
    matches = re.findall(pattern, text)
    return matches

def process_text(text):
    """直接处理输入的文本并提取双引号内容"""
    quoted_content = extract_quoted_content(text)
    candidate_cmdi_list = list()
    if quoted_content:
        for i, item in enumerate(quoted_content, 1):
            candidate_cmdi = item.replace("\n","")
            if ".lua" in candidate_cmdi.lower():
                return candidate_cmdi

def find_cmdi_folders(root_dir):
    cmdi_folders = []
    for root, dirs, _ in os.walk(root_dir):
        for dir_name in dirs:
            if dir_name == 'cmdi_closures':
                cmdi_folders.append(os.path.join(root, dir_name))
    return cmdi_folders

def split_cmd_str(cmd_str):
    # s = "/dumaos/fxcn_soap_auth.lua '<BV32 TOP>' 1>/dev/null"

    # 使用正则表达式分割字符串，保留引号内的内容
    parts = re.findall(r'''(["'])(.*?)\1|(\S+)''', cmd_str)

    # 处理匹配结果，提取实际内容
    result = []
    for match in parts:
        if match[1]:  # 匹配到引号内的内容
            result.append(match[1])
        else:  # 匹配到普通文本
            result.append(match[2])

    # print(result)
    # 输出: ['/dumaos/fxcn_soap_auth.lua', '<BV32 TOP>', '1>/dev/null']
    return result
    
def get_cmdi_list(cmdi_folder_path):
    IPC_cmdi_list = list()
    for filename in os.listdir(cmdi_folder_path):
        file_path = os.path.join(cmdi_folder_path, filename)
        try:
            if os.path.isfile(file_path):
                with open(file_path, 'r', encoding='utf-8') as file:
                    
                    content = file.read()
                    candidate_cmdi = process_text(content)
                    if candidate_cmdi:
                        # set_trace()
                        lua_file_idx = None
                        # cmdi_split = candidate_cmdi.split()
                        cmdi_split = split_cmd_str(candidate_cmdi)
                        for i, cmdi in enumerate(cmdi_split):
                            if ".lua" in cmdi.lower():
                                lua_file_idx = i
                        cmdline_param_idx = list()
                        for i, cmdi in enumerate(cmdi_split):
                            if lua_file_idx != None:
                                if i > lua_file_idx:
                                    if 'TOP' in cmdi or "<BV" in cmdi:
                                        cmdline_param_idx.append(i-lua_file_idx)
                        IPC_cmdi_list.append([file_path, candidate_cmdi, candidate_cmdi[lua_file_idx], cmdline_param_idx])
                        # print(os.path.basename(file_path))
                        # print(f"{file_path:<50}", candidate_cmdi, cmdline_param_idx)
        except Exception as e:
            print(f"访问文件夹时出错: {e}")
        return IPC_cmdi_list

def search_for_lua_vulnerability(search_report_dir, lua_file, cmdline_param_idx):
    lua_vul_list = list()
    base_lua_file = os.path.basename(lua_file)
    for filename in os.listdir(search_report_dir):
        report_path = os.path.join(search_report_dir, filename)
        if base_lua_file in report_path:
            for cmd_idx in cmdline_param_idx:
                if f"(No.{cmd_idx}" in report_path:
                    lua_vul_list.append(report_path)
    return lua_vul_list

def search_cross_language_IPC_Vul_C_to_Lua(C_report_dir, Lua_report_dir, Cross_language_IPC_result_path):
    vendor_lua_cmdline_vul = list()
    IPC_cmdi_list_vendor = list()
    cmdi_folders = find_cmdi_folders(C_report_dir)
    # print(len(cmdi_folders))
    for cmdi_folder in cmdi_folders:
        IPC_cmdi_list_bin = get_cmdi_list(cmdi_folder)
        IPC_cmdi_list_vendor.extend(IPC_cmdi_list_bin)
    for IPC_cmd_info in IPC_cmdi_list_vendor:
        file_path, cmdi, lua_file, cmdline_param_idx = IPC_cmd_info
        
        # print(f"""
        #     file_path: {file_path}
        #     \t cmdi: {cmdi}
        #     \t lua_file: {lua_file}
        #     \t cmdline_param_idx: {cmdline_param_idx}
        # """)

        rank = 0
        try:
            rank =float(os.path.basename(file_path).split("_")[0])
        except:
            continue

        if rank > 0.6:
            lua_vul_list = search_for_lua_vulnerability(Lua_report_dir, lua_file, cmdline_param_idx)
            for lua_report_path in lua_vul_list:
                record = {
                    "C_report": file_path,
                    "C_cmd": cmdi,
                    "target_lua_file": lua_file,
                    "target_cmd_list": cmdline_param_idx,
                    "Lua_report": lua_report_path
                }
                vendor_lua_cmdline_vul.append(record)
    if vendor_lua_cmdline_vul:
        if not os.path.exists(Cross_language_IPC_result_path):
            os.makedirs(Cross_language_IPC_result_path, exist_ok=True)
        result_path = os.path.join(Cross_language_IPC_result_path, "C2Lua_IPC_Vul")
        with open(result_path, "w") as f:
            json.dump(vendor_lua_cmdline_vul, f, indent=4)

def main():
    netgear_path = "/data/lrh/first_work/mango_dfa_result/73fw/sample_60_fw/netgear_new/126_120/"
    # netgear_path = "/data/lrh/first_work/mango_dfa_result/73fw/sample_60_fw/netgear_new/"
    # netgear_path = "/data/lrh/first_work/mango_dfa_result/73fw/sample_60_fw/"
    # netgear_path = "/data/lrh/first_work/mango_dfa_result/73fw/"
    search_report_dir = ""
    result_save_path = ""
    vendor_lua_cmdline_vul = list()
    IPC_cmdi_list_vendor = list()
    cmdi_folders = find_cmdi_folders(netgear_path)
    # print(len(cmdi_folders))
    for cmdi_folder in cmdi_folders:
        IPC_cmdi_list_bin = get_cmdi_list(cmdi_folder)
        IPC_cmdi_list_vendor.extend(IPC_cmdi_list_bin)
    for IPC_cmd_info in IPC_cmdi_list_vendor:
        file_path, cmdi, lua_file, cmdline_param_idx = IPC_cmd_info
        
        # print(f"""
        #     file_path: {file_path}
        #     \t cmdi: {cmdi}
        #     \t lua_file: {lua_file}
        #     \t cmdline_param_idx: {cmdline_param_idx}
        # """)

        rank = 0
        try:
            rank =float(os.path.basename(file_path).split("_")[0])
        except:
            continue

        if rank > 0.6:
            lua_vul_list = search_for_lua_vulnerability(search_report_dir, lua_file, cmdline_param_idx)
            for lua_report_path in lua_vul_list:
                record = {
                    "C_report": file_path,
                    "C_cmd": cmdi,
                    "target_lua_file": lua_file,
                    "target_cmd_list": cmdline_param_idx,
                    "Lua_report": lua_report_path
                }
                vendor_lua_cmdline_vul.append(record)
    if vendor_lua_cmdline_vul:
        with open(result_save_path, "w") as f:
            json.dump(vendor_lua_cmdline_vul, f, indent=4)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python script.py C_report_path Lua_report_path Cross_language_IPC_Vul_dir")
        sys.exit(1)

    C_report_path = sys.argv[1]
    Lua_report_path = sys.argv[2]
    Cross_language_IPC_Vul_dir = sys.argv[3]

    search_cross_language_IPC_Vul_C_to_Lua(C_report_path, Lua_report_path, Cross_language_IPC_Vul_dir)