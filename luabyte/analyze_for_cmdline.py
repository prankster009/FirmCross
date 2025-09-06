#!/usr/bin/env python3
import sys
from utils.logger import init_logger_path

# the init_logger_path must execute before import Whole_Module
fw_path = "/home/iot_2204/lua_analysis/Luabyte_Taint_large_test/test_case/cmdline_test/src/cmdline2.luac"
output_dir = "/home/iot_2204/lua_analysis/Luabyte_Taint_large_test/test_case/cmdline_test/result"
init_logger_path(output_dir)


from analysis.module import Whole_Module
from ipdb import set_trace
# set_trace()
whole_module = Whole_Module(
                            fw_path=fw_path, 
                            output_dir=output_dir, 
                            resolve_source=True, 
                            is_vul_discover=True, 
                            debug = True
                        )