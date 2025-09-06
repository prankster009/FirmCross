#!/bin/bash

Lua_table_path="$(pwd)/result_one_xiaomi_fw/single_lua/lua_table/lua_table"
Lua_table_sink_dir="$(pwd)/result_one_xiaomi_fw/single_lua/vul_report_lua/lua_table_sink"
EXISTING_DATASET_PATH="$(pwd)/dataset_one_xiaomi_fw"
C2Lua_API_vul_DIR="$(pwd)/result_one_xiaomi_fw/cross_vul/API_vul/Lua2C/"
mkdir -p "$C2Lua_API_vul_DIR"


Scan_PY="./detect_API_Lua2C_vul.py"

python "${Scan_PY}" "${Lua_table_path}" "${Lua_table_sink_dir}" "${EXISTING_DATASET_PATH}" "${C2Lua_API_vul_DIR}" 
