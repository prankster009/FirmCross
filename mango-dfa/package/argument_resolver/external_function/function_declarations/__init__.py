import os
import json
import re

from .nvram import libnvram_decls
from .win32 import winreg_decls
from .custom import custom_decls

from angr.sim_type import (
    SimTypeFunction,
    SimTypeInt,
    SimTypePointer,
    SimTypeChar,
    SimTypeTop,
    SimTypeBottom,
)

from argument_resolver.external_function.input_functions import update_INPUT_EXTERNAL_FUNCTIONS


CUSTOM_DECLS = {**libnvram_decls, **winreg_decls, **custom_decls}

def get_CUSTOM_DECLS():
    global CUSTOM_DECLS
    return CUSTOM_DECLS

def update_CUSTOM_DECLS(decls_dict):
    global CUSTOM_DECLS
    CUSTOM_DECLS.update(decls_dict)


def get_decls(name, param_idx):
    decls = dict()
    args_list = list()
    args_names = list()
    for i in range(param_idx+1):
        args_list.append(SimTypePointer(SimTypeTop(), offset=0))
        args_names.append("unknown")
    
    decls[name] = SimTypeFunction(
        args_list,
        SimTypeInt(signed=True),  
        args_names
    )

    return decls

def read_lua2c_API_info_and_update_CUSTOM_DECLS(lua2c_API_path):
    if os.path.exists(lua2c_API_path) and os.path.isdir(lua2c_API_path):
        for file in os.listdir(lua2c_API_path):
            abs_file = os.path.join(lua2c_API_path, file)
            report_info = ""
            with open(abs_file) as f:
                report_info = f.read()
            pattern = re.compile(
                r'Vulnerability (\d+):.*?'
                r'Source.*?File: (.*?), Function: (.*?)\s+pc: (-?\d+), trigger: "(.*?)".*?'
                r'Sink.*?File: (.*?), Function: (.*?)\s+pc: (-?\d+), trigger: "(.*?)", param idx: (\d+).*?',
                re.DOTALL
            )
            # set_trace()
            for match in re.finditer(pattern, report_info):
                C_function_name = match.group(9)
                param_idx = match.group(10)
                if C_function_name and param_idx:
                    update_INPUT_EXTERNAL_FUNCTIONS(C_function_name)
                    decls_instance = get_decls(C_function_name, param_idx)
                    update_CUSTOM_DECLS(decls_instance)


    
