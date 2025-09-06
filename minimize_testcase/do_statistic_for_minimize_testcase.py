#!/usr/bin/env python3
import sys
import os
sys.path.append("../result_statistic")

from cross_communication.do_statistic_for_cross_communication import get_IPC_times, get_API_times, get_API_times2
from cross_vul.do_statistic_for_cross_vul import get_num_IPC_Lua2C_vul, get_num_IPC_C2Lua_vul, get_num_API_C2Lua_vul, get_num_API_Lua2C_vul
from c_vul.do_statistic_c_vul import parse_mango_result, get_alerts_and_time
from lua_vul.do_statistic_vul import travel_vul_report
from source_identify.do_statistic_source_identify import get_source_num

def get_real_fs_path(fs_path):
    if fs_path.endswith("squashfs-root"):
        return fs_path
    for root, dirs, files in os.walk(fs_path):
        if root.endswith("squashfs-root"):
            return root

def get_cross_language_communication_times(lua_result_path, fs_path):
    IPC_path = os.path.join(lua_result_path, "Lua_to_C/IPC")
    sink_info_path = os.path.join(lua_result_path,"sink_identify/sink")
    lua_table_path = os.path.join(lua_result_path,"lua_table/lua_table")

    real_fs_path = get_real_fs_path(fs_path)

    IPC_times = get_IPC_times(IPC_path, real_fs_path)
    # API_times = get_API_times(sink_info_path)
    API_times = get_API_times2(lua_table_path)

    return IPC_times, API_times

def get_cross_vul_nums(cross_vul_result_path):
    Lua2C_IPC_vul_path = os.path.join(cross_vul_result_path, "IPC_vul/Lua2C_IPC_Vul")
    IPC_Lua2C_num = get_num_IPC_Lua2C_vul(Lua2C_IPC_vul_path)
    # print(f"IPC_Lua2C_num: {IPC_Lua2C_num}")

    C2Lua_IPC_vul_path = os.path.join(cross_vul_result_path, "IPC_vul/C2Lua_IPC_Vul")
    IPC_C2Lua_num = get_num_IPC_C2Lua_vul(C2Lua_IPC_vul_path)
    # print(f"IPC_C2Lua_num: {IPC_C2Lua_num}")

    C2Lua_API_vul_path = os.path.join(cross_vul_result_path, "API_vul/C2Lua/API_Vul")
    API_C2Lua_num = get_num_API_C2Lua_vul(C2Lua_API_vul_path)
    # print(f"API_C2Lua_num: {API_C2Lua_num}")

    Lua2C_API_vul_path = os.path.join(cross_vul_result_path, "API_vul/Lua2C")
    API_Lua2C_num = get_num_API_Lua2C_vul(Lua2C_API_vul_path)
    # print(f"API_Lua2C_num: {API_Lua2C_num}")

    total_cross_vul_num = IPC_Lua2C_num + IPC_C2Lua_num + API_C2Lua_num + API_Lua2C_num

    return total_cross_vul_num


def get_c_vul_nums(c_result_path):
    results = parse_mango_result(c_result_path, None)
    Alerts, AVG_Time = get_alerts_and_time(results, False)
    return Alerts

def get_lua_vul_nums(lua_result_path):
    vul_record = travel_vul_report(lua_result_path)
    return len(vul_record)

def get_source_nums(lua_result_path):
    source_num = get_source_num(lua_result_path)
    return source_num

if __name__ == "__main__":
    # if len(sys.argv) != 5:
    #     print("Usage: python script.py lua_result_path, c_result_path, cross_result_path, fs_path")
    #     sys.exit(1)

    # lua_result_path = sys.argv[1]
    # c_result_path = sys.argv[2]
    # cross_result_path = sys.argv[3]
    # fs_path = sys.argv[4]

    lua_result_path = "./result/single_lua"
    c_result_path = "./result/single_c"
    cross_result_path = "./result/cross_vul/"
    fs_path = "./test_fw/"

    # print(cross_result_path==cross_result_path2)


    IPC_times, API_times = get_cross_language_communication_times(lua_result_path, fs_path)
    total_cross_communication_times = IPC_times + API_times
    

    source_num = get_source_nums(lua_result_path)
    

    lua_vul_num = get_lua_vul_nums(lua_result_path)
    # print(f"lua_vul_num: {lua_vul_num}")

    c_vul_num = get_c_vul_nums(c_result_path)
    c_vul_num = int(c_vul_num)
    # print(f"c_vul_num: {c_vul_num}")

    cross_vul_num = get_cross_vul_nums(cross_result_path)
    # print(f"cross_vul_num: {cross_vul_num}")

    total_vuls = lua_vul_num + c_vul_num + cross_vul_num

    print(f"(C1)totoal_vul: {total_vuls}\n\tlua_vul: {lua_vul_num}\n\tc_vul: {c_vul_num}\n\tcross_vul: {cross_vul_num}")
    print(f"(C2)identified source: {source_num}")
    print(f"(C3)total_times: {total_cross_communication_times}\n\tIPC_times: {IPC_times}\n\tAPI_times: {API_times}")






