from ipdb import set_trace
import os
import re
import subprocess
import re
import subprocess
import shlex

def execute_cmd(cmd):
    # set_trace()
    command = shlex.split(cmd)
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)  
    return result.returncode, result.stderr, result.stdout


def has_luaopen_function():
    # 遍历当前目录中的所有文件
    current_dir = "/home/iot_2204/database_firmware/manual_test/ruijie/cn/RG-EW3200GX/_EW_3.0(1)B11P227_EW3200GX_11140506_install_encypto.bin.decrypted.extracted/squashfs-root/usr/lib/lua"
    so_file_list = list()
    # 遍历当前目录下的所有文件
    for root, dirs, files in os.walk(current_dir):
        for file in files:
            if file.endswith('.so'):
                so_file = os.path.join(root, file)
                # 检查是否存在 luaopen_ 函数

        
                basename = os.path.splitext(file)[0]
                # if basename == "lfs":
                #     set_trace()
                expected_func = f'luaopen_{basename}'
                
                cmd = f"nm -D '{so_file}'"
                returncode, return_stderr, output = execute_cmd(cmd)
                if returncode != 0:
                    error_msg = f"{basename} error, error msg:{return_stderr}"
                    print(error_msg)
                    continue

                # 解析nm输出，查找目标函数
                for line in output.splitlines():
                    parts = line.strip().split()
                    if len(parts) < 3:
                        continue
                    # 提取符号类型和名称
                    sym_addr, sym_type, sym_name = parts[0], parts[1], ' '.join(parts[2:])
                    # 检查是否为全局函数且名称匹配
                    if sym_type in ('T', 't') and sym_name == expected_func:
                        # set_trace()
                        # print(f'{so_file}: True')
                        so_file_list.append(so_file)
    return so_file_list

def get_func_info(output_text):
    # # 输入文本（示例）
    # text = """
    # Function Name: luaopen_luacurl, Address: 0x1234abcd
    # Function Name: curl_init, Address: 0x55aabbcc
    # Invalid行: Function Name: bad_addr, Address: 0xzzz
    # """

    # 定义正则表达式
    pattern = r"Function Name: (.+?), Address: 0x([0-9a-fA-F]+)"
    matches = re.findall(pattern, output_text)

    result = list()
    # 输出结果
    if matches:
        for name, addr in matches:
            result.append((name, int(addr,16)))
    return result

# 调用函数并输出结果
so_file_list = has_luaopen_function()
for so_file in so_file_list:
    # set_trace()
    cmd = f"mango '{so_file}' --results /home/iot_2204/operation-mango-public/package/tests/my_test/test_lua_register/ -c lua_register"
    returncode, return_stderr, output = execute_cmd(cmd)
    basename = os.path.basename(so_file)
    if returncode != 0:
        error_msg = f"{basename} error, error msg:{return_stderr}"
        print(error_msg)
        continue
    func_info_list = get_func_info(output)
    if func_info_list: 
        print(f"{basename} register table_info:")
        for name, addr in func_info_list:
            print(f"\t func_name: {name:<20}, addr: 0x{addr:x}")