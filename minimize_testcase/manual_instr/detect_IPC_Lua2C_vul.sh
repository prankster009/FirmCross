#!/bin/bash

Lua2C_IPC_path="$(pwd)/result_one_xiaomi_fw/single_lua/Lua_to_C/IPC"
fs_path="$(pwd)/dataset_one_xiaomi_fw/xiaomi/"
C_report_path="$(pwd)/result_one_xiaomi_fw/single_c/"
Cross_language_vul_path="$(pwd)/result_one_xiaomi_fw/cross_vul/IPC_vul"
mkdir -p "$Cross_language_vul_path"

# Scan_PY=$(readlink -f "$(pwd)/../mango-dfa/scan_IPC_vul/C2Lua/scan_cross_language_IPC_Vul_C_to_Lua.py")
Scan_PY="$(pwd)/../mango-dfa/scan_IPC_vul/Lua2C/scan_cross_language_IPC_Vul_Lua_to_C.py"

python "${Scan_PY}" "${Lua2C_IPC_path}" "${fs_path}" "${C_report_path}" "${Cross_language_vul_path}"
