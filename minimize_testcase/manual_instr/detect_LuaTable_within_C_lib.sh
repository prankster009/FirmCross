#!/bin/bash

EXISTING_DATASET_PATH=$(readlink -f "$(pwd)/dataset_one_xiaomi_fw")
EXISTING_RESULTS_DIR="$(pwd)/result_one_xiaomi_fw/single_lua"
mkdir -p "$EXISTING_RESULTS_DIR"

Scan_PY=$(readlink -f "$(pwd)/../luabyte/detect_LuaTable_within_C_lib.py")

python "${Scan_PY}" "${EXISTING_DATASET_PATH}" "${EXISTING_RESULTS_DIR}"
