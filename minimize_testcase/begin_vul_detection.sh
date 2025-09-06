#!/bin/bash

EXISTING_DATASET_PATH=$(readlink -f "$(pwd)/test_fw")
EXISTING_RESULTS_DIR="$(pwd)/result"

py_lua_env="$(pwd)/../firmcross_ae_lua"
py_c_env="$(pwd)/../firmcross_ae"

# 1. Vul detection for Lua module

echo "Vul detection for Lua module"

# 1.1. Detect lua function within c lib 
source "$py_c_env/bin/activate"
Single_Lua_RESULTS_DIR="$EXISTING_RESULTS_DIR/single_lua"
mkdir -p "$Single_Lua_RESULTS_DIR"

Scan_PY=$(readlink -f "$(pwd)/../luabyte/detect_LuaTable_within_C_lib.py")
python "${Scan_PY}" "${EXISTING_DATASET_PATH}" "${Single_Lua_RESULTS_DIR}"

deactivate

# 1.2 begin vul detection for lua module
source "$py_lua_env/bin/activate"

Scan_PY=$(readlink -f "$(pwd)/../luabyte/scan_vul_for_lua_module.py")
python "${Scan_PY}" "${EXISTING_DATASET_PATH}" "${Single_Lua_RESULTS_DIR}"

deactivate

# 2. Vul detection for C Module

echo "Vul detection for C module"

source "$py_c_env/bin/activate"

Single_C_RESULTS_DIR="$EXISTING_RESULTS_DIR/single_c"
mkdir -p "$Single_C_RESULTS_DIR"

PARALLEL_NUM=40

MANGO_PIPELINE=$(readlink -f "$(pwd)/../firmcross_ae/bin/mango-pipeline")

# nvram parse
$MANGO_PIPELINE --path $EXISTING_DATASET_PATH --results $Single_C_RESULTS_DIR --env --parallel $PARALLEL_NUM

# analysis for cmd injection
$MANGO_PIPELINE --path $EXISTING_DATASET_PATH --results $Single_C_RESULTS_DIR --mango --parallel $PARALLEL_NUM

# analysis for buffer overflow
$MANGO_PIPELINE --path $EXISTING_DATASET_PATH --results $Single_C_RESULTS_DIR --mango --parallel $PARALLEL_NUM --category overflow

deactivate

# 3. Vul detection for Cross language

echo "Vul detection for Cross language"

# 3.1 IPC C2Lua detection
source "$py_lua_env/bin/activate"

Lua_report_path="$Single_Lua_RESULTS_DIR/vul_report_lua"
Cross_language_vul_path="$EXISTING_RESULTS_DIR/cross_vul/IPC_vul"
mkdir -p "$Cross_language_vul_path"

Scan_PY=$(readlink -f "$(pwd)/../mango-dfa/scan_IPC_vul/C2Lua/scan_cross_language_IPC_Vul_C_to_Lua.py")
python "${Scan_PY}" "${Single_C_RESULTS_DIR}" "${Lua_report_path}" "${Cross_language_vul_path}"

deactivate

# 3.2 IPC Lua2C detection
source "$py_c_env/bin/activate"

Lua2C_IPC_path="$Single_Lua_RESULTS_DIR/Lua_to_C/IPC"

Scan_PY="$(pwd)/../mango-dfa/scan_IPC_vul/Lua2C/scan_cross_language_IPC_Vul_Lua_to_C.py"
python "${Scan_PY}" "${Lua2C_IPC_path}" "${EXISTING_DATASET_PATH}" "${Single_C_RESULTS_DIR}" "${Cross_language_vul_path}"

deactivate

# 3.3 API Lua2C detection
source "$py_c_env/bin/activate"

Lua_table_path="$Single_Lua_RESULTS_DIR/lua_table/lua_table"
Lua_table_sink_dir="$Single_Lua_RESULTS_DIR/vul_report_lua/lua_table_sink"
C2Lua_API_vul_DIR="$EXISTING_RESULTS_DIR/cross_vul/API_vul/Lua2C/"
mkdir -p "$C2Lua_API_vul_DIR"


Scan_PY="./detect_API_Lua2C_vul.py"
python "${Scan_PY}" "${Lua_table_path}" "${Lua_table_sink_dir}" "${EXISTING_DATASET_PATH}" "${C2Lua_API_vul_DIR}" 

source "$py_c_env/bin/activate"

# 3.4 API C2Lua detection
source "$py_lua_env/bin/activate"

API_C2Lua_RESULTS_DIR="$EXISTING_RESULTS_DIR/cross_vul/API_vul/C2Lua/API_info"
mkdir -p "$API_C2Lua_RESULTS_DIR"

Scan_PY="$(pwd)/../mango-dfa/scan_API_Cross_vul/C2Lua/detect_C2Lua_API_info.py"
python "${Scan_PY}" "${EXISTING_DATASET_PATH}" "${API_C2Lua_RESULTS_DIR}"

C2Lua_API_vul_DIR="$EXISTING_RESULTS_DIR/cross_vul/API_vul/C2Lua/API_Vul"
mkdir -p "$C2Lua_API_vul_DIR"

Scan_PY="$(pwd)/../luabyte/detect_vul_related_to_C2LuaAPI.py"
python "${Scan_PY}" "${EXISTING_DATASET_PATH}" "${API_C2Lua_RESULTS_DIR}" "${C2Lua_API_vul_DIR}"

deactivate
