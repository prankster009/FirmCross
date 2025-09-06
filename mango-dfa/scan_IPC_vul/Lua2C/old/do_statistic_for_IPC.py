import os
import sys
import json
from ipdb import set_trace


def do_statistic_IPC_for_13fw():
    result_path = "fw_cmd_json_13_fw"
    with open(result_path) as f:
        results = json.load(f)
    for product, cmd_list in results.items():
        print(product, len(cmd_list))

def do_statistic_IPC_for_60fw():
    result_path = "fw_cmd_json"
    with open(result_path) as f:
        results = json.load(f)
    for product, cmd_list in results.items():
        print(product, len(cmd_list))
    # set_trace()

if __name__ == "__main__":
    do_statistic_IPC_for_60fw()
    print("13_Fw")
    do_statistic_IPC_for_13fw()