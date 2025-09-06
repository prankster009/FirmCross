from ipdb import set_trace
import os
import re
import subprocess
import shutil
import shlex
import json
import sys
import string
import random

def execute_cmd(cmd):
    # set_trace()
    command = shlex.split(cmd)
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)  
    return result.returncode, result.stderr, result.stdout


def has_luaopen_function(squashfs_path):
    # 遍历当前目录中的所有文件
    so_file_list = list()
    # 遍历当前目录下的所有文件
    for root, dirs, files in os.walk(squashfs_path):
        for file in files:
            if file.endswith('.so'):
                so_file = os.path.join(root, file)
                # 检查是否存在 luaopen_ 函数

                basename = os.path.splitext(file)[0]
                # if basename == "lfs":
                #     set_trace()
                expected_func = f'luaopen_{basename}'
                
                # cmd = f"nm -D '{so_file}'"
                cmd = f"strings '{so_file}'"
                # print(cmd)
                # set_trace()
                # if "nixio.so" in so_file:
                #     set_trace()
                returncode, return_stderr, output = execute_cmd(cmd)
                if returncode != 0:
                    error_msg = f"{basename} error, error msg:{return_stderr}"
                    # print(error_msg)
                    continue
                
                # luaL_register
                # luaopen_xxx
                register_find = False
                wrapper_find = False
                wrapper_name = f"luaopen_{os.path.basename(so_file)[:-3]}"

                # 解析nm输出，查找目标函数
                for line in output.splitlines():
                    if line == "luaL_register":
                        register_find = True
                    elif line == wrapper_name:
                        wrapper_find = True
                    if wrapper_find and register_find:
                        so_file_list.append(so_file)
                        break
                    # parts = line.strip().split()
                    # if len(parts) < 3:
                    #     continue
                    # # 提取符号类型和名称
                    # sym_addr, sym_type, sym_name = parts[0], parts[1], ' '.join(parts[2:])
                    # # 检查是否为全局函数且名称匹配
                    # if sym_type in ('T', 't') and sym_name == expected_func:
                    #     # set_trace()
                    #     # print(f'{so_file}: True')
                    #     so_file_list.append(so_file)
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

def random_string(length=5):
    characters = string.ascii_letters + string.digits  # 包含大小写字母和数字
    return ''.join(random.choices(characters, k=length))

def get_lua_table(squashfs_path, output_dir):
    # set_trace()
    # 调用函数并输出结果
    so_file_list = has_luaopen_function(squashfs_path)
    # for so_file in so_file_list:
    #     print(so_file)
    # sys.exit(0)
    random_suffix = random_string()
    tmp_output = f"/tmp/tmp_mango_identify_luatable_{random_suffix}"
    result = dict()
    if not os.path.exists(tmp_output):
        os.mkdir(tmp_output)
    for so_file in so_file_list:
        # set_trace()
        cmd = f"mango '{so_file}' --results {tmp_output} -c lua_register"
        returncode, return_stderr, output = execute_cmd(cmd)
        basename = os.path.basename(so_file)
        if returncode != 0:
            # error_msg = f"{basename} error, error msg:{return_stderr}"
            error_msg = f"{basename} error, error_msg: {return_stderr}"
            # print(error_msg)
            continue
        func_info_list = get_func_info(output)
        if func_info_list: 
            result[basename] = list()
            # print(f"{basename} register table_info:")
            for name, addr in func_info_list:
                print(f"\t func_name: {name:<20}, addr: 0x{addr:x}")
                info = {
                    "name": name,
                    "addr": addr
                }
                result[basename].append(info)
        else:
            pass
            # print(f"can not find lua table in {so_file}")
    if os.path.exists(tmp_output):
        shutil.rmtree(tmp_output)
    output_path = os.path.join(output_dir, "lua_table")
    if not os.path.exists(output_path):
        os.makedirs(output_path, exist_ok=True)
    file_name = os.path.join(output_path, "lua_table")
    with open(file_name, "w+") as f:
        json.dump(result, f, indent=4)


def save_lua_table_json(brand, squashfs_info, output_dir, logger):
    # detect lua table

    image_id = squashfs_info["image_id"]
    product_id = squashfs_info["product_id"]
    squashfs_path = squashfs_info["rootfs_path"]

    try:
        cmd = f"/home/nudt/lrh/first_work/luabyte_taint_larget_test_branch/identify_lua_table.sh '{squashfs_path}' '{output_dir}'"
        returncode, return_stderr, output = execute_cmd(cmd)
        if returncode != 0:
            error_msg = f"detect lua table, error msg:{return_stderr}"
            logger.error(error_msg)
        logger.info(output)
        return {"image_id": image_id, "product_id": product_id, "status": "success"}
    except Exception as e:
        error_message = f"Error processing brand {brand} with image_id {image_id} and product_id {product_id}: {e}"
        logger.error(error_message)
        return {"image_id": image_id, "product_id": product_id, "status": "error", "error_message": str(e)}

def save_lua_table_json_for_existing_dataset(product, squashfs_path, output_dir, logger):
    try:
        cmd = f"/home/nudt/lrh/first_work/luabyte_taint_larget_test_branch/identify_lua_table.sh '{squashfs_path}' '{output_dir}'"
        returncode, return_stderr, output = execute_cmd(cmd)
        if returncode != 0:
            error_msg = f"detect lua table, error msg:{return_stderr}"
            logger.error(error_msg)
        logger.info(output)
        return {"product": product, "status": "success"}
    except Exception as e:
        error_message = f"Error processing product {product} : {e}"
        logger.error(error_message)
        return {"product": product, "status": "error", "error_message": str(e)}

if __name__ == "__main__":
    # 检查命令行参数的数量是否为 2（不包括脚本名本身）
    if len(sys.argv) != 3:
        print("错误：需要提供两个命令行参数。")
        print("用法：python script.py arg1 arg2")
        sys.exit(1)


    squashfs_path = sys.argv[1]
    output_dir = sys.argv[2]


    get_lua_table(squashfs_path, output_dir)