#!/bin/bash

# 检查参数数量
if [ $# -ne 2 ]; then
    echo "用法: $0 <squashfs_path> <output_dir>"
    echo "示例: $0 \"/path/to/squashfs\" \"/path/to/output\""
    exit 1
fi

# 从命令行参数获取路径
squashfs_path="$1"
output_dir="$2"

# 固定路径（也可以改为参数）
venv_path="/home/nudt/lrh/first_work/mango-dfa/mango_vir_env_python_3.11"
script_path="./analysis/identify_lua_table.py"

# 创建输出目录
mkdir -p "$output_dir"

# 执行命令
source "${venv_path}/bin/activate" && \
python3 "${script_path}" "${squashfs_path}" "${output_dir}" && \
deactivate