#!/bin/bash

C_report_path=$(readlink -f "$(pwd)/result_one_xiaomi_fw/single_c/")
Lua_report_path=$(readlink -f "$(pwd)/result_one_xiaomi_fw/single_lua/vul_report_lua")
Cross_language_vul_path="$(pwd)/result_one_xiaomi_fw/cross_vul/IPC_vul"
mkdir -p "$Cross_language_vul_path"

Scan_PY=$(readlink -f "$(pwd)/../mango-dfa/scan_IPC_vul/C2Lua/scan_cross_language_IPC_Vul_C_to_Lua.py")

python "${Scan_PY}" "${C_report_path}" "${Lua_report_path}" "${Cross_language_vul_path}"
