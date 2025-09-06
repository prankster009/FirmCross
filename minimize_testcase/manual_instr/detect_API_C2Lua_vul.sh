#!/bin/bash

EXISTING_DATASET_PATH="$(pwd)/dataset_one_xiaomi_fw"
C2Lua_API_info_DIR="$(pwd)/result_one_xiaomi_fw/cross_vul/API_vul/C2Lua/API_info"
C2Lua_API_vul_DIR="$(pwd)//result_one_xiaomi_fw/cross_vul/API_vul/C2Lua/API_Vul"
mkdir -p "$C2Lua_API_vul_DIR"

Scan_PY="$(pwd)/../luabyte/detect_vul_related_to_C2LuaAPI.py"

python "${Scan_PY}" "${EXISTING_DATASET_PATH}" "${C2Lua_API_info_DIR}" "${C2Lua_API_vul_DIR}"
