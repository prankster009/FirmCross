import os 
from do_statistic_vul import vul_brand_path, travel_vul_report
from ipdb import set_trace

if __name__ == "__main__":
    cudy_vendor_path = "/data/lrh/first_work/firmcross_ae/minimize_testcase/result_one_xiaomi_fw/single_lua"
    xlsx_path = "/data/lrh/first_work/firmcross_ae/minimize_testcase/result_one_xiaomi_fw/single_lua/minimize.xlsx"
    vul_record = travel_vul_report(cudy_vendor_path)
    print(len(vul_record))
