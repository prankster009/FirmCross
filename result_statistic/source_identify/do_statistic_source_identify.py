import os
import sys
import json
from collections import defaultdict

def get_source_num(result_path):
    for root, dirs, files in os.walk(result_path):
        for file in files:
            if file.endswith("source"):
                source_path = os.path.join(root, file)
                source_list = list()
                with open(source_path) as f:
                    source_list = json.load(f)
                source_num = len(source_list)
                return source_num


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py result_path")
        sys.exit(1)

    result_path = sys.argv[1]
    get_source_num(result_path)

    # python do_statistic_source_identify.py /data/lrh/first_work/firmcross_ae/minimize_testcase/result_one_xiaomi_fw/single_lua
