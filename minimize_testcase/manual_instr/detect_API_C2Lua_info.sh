#!/bin/bash

EXISTING_DATASET_PATH="$(pwd)/dataset_one_xiaomi_fw"
EXISTING_RESULTS_DIR="$(pwd)/result_one_xiaomi_fw/cross_vul/API_vul/C2Lua/API_info"
mkdir -p "$EXISTING_RESULTS_DIR"

Scan_PY="$(pwd)/../mango-dfa/scan_API_Cross_vul/C2Lua/detect_C2Lua_API_info.py"

python "${Scan_PY}" "${EXISTING_DATASET_PATH}" "${EXISTING_RESULTS_DIR}"
