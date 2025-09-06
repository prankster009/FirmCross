#!/bin/bash

EXISTING_DATASET_PATH=$(readlink -f "$(pwd)/dataset_one_xiaomi_fw")

EXISTING_RESULTS_DIR="$(pwd)/result_one_xiaomi_fw/single_c"
mkdir -p "$EXISTING_RESULTS_DIR"

PARALLEL_NUM=40

MANGO_PIPELINE=$(readlink -f "$(pwd)/../py_firmcross_C_lua/bin/mango-pipeline")

# echo $EXISTING_DATASET_PATH
# echo $EXISTING_RESULTS_DIR
# echo $MANGO_PIPELINE


# 运行环境/nvram 值解析
$MANGO_PIPELINE --path $EXISTING_DATASET_PATH --results $EXISTING_RESULTS_DIR --env --parallel $PARALLEL_NUM

# 运行命令注入的 mango 分析
$MANGO_PIPELINE --path $EXISTING_DATASET_PATH --results $EXISTING_RESULTS_DIR --mango --parallel $PARALLEL_NUM

# 运行缓冲区溢出的 mango 分析
$MANGO_PIPELINE --path $EXISTING_DATASET_PATH --results $EXISTING_RESULTS_DIR --mango --parallel $PARALLEL_NUM --category overflow