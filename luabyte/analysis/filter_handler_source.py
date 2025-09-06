import os
import sys
sys.path.append("..")
from typing import List, Dict, Tuple, Optional
from cfg.cfg import CFG
from utils.logger import setup_logger
from cfg.cfg import CFG, LuaB_Param_Block, LuaB_Block
from cfg.high_instruction import CallInstr, Register
from cfg.cg import search_cfg_in_whole_module
from analysis.constant_propagation import get_concrete_value, Load_Module, get_callee_name, get_constant, ConstantType, get_constant_info_of_RK
from ipdb import set_trace
import networkx
from enum import Enum
import re
from vulnerabilities.source_sink_identify import Source_Sink_Type, Source_Param_Trigger, Sink_Instr_Trigger
from vulnerabilities.vulnerabilities import taint_propagation_source_to_sink, get_usage_chains
from datetime import datetime

# logger = setup_logger(__name__, log_to_file=True, log_filename='LuabyteTaint_source.log')
# logger = setup_logger(__name__, log_to_file=True, log_filename='filter_handler_source.log', level=1)
logger = setup_logger(__name__)
# print(logger.__dict__)

class Source_Identify:
    def __init__(self, register_name:str, register_param_idx:int, nested_access:Dict, event_handler:List):
        self.register_name = register_name
        self.register_param_idx = register_param_idx
        self.nested_access = nested_access
        self.event_handler = event_handler

def get_param_value_in_filtering_event_handler(cfg, block, pc, param_reg_idx):
    constant_list = cfg.constant_propagation.get_constant_before_pc(block, pc)
    constant_instance = get_constant(constant_list, param_reg_idx)
    if constant_instance.type == ConstantType.Constant:
        return constant_instance.value
    elif constant_instance.type == ConstantType.Table:
        return constant_instance.value
    else:
        return None

def check_func_in_nested_struct(nest_struct:dict, whole_module):
    founded_func = list()
    for key, values_tuple in nest_struct.items():
        constant_type, constant_value = values_tuple
        if isinstance(constant_value, CFG):
            founded_func.append(constant_value)
        # TODO: do Load_Module need ?
        elif isinstance(constant_value, Load_Module):
            founded_func.append(get_cfg_instance_of_Load_Module(constant_value, whole_module))
        elif isinstance(constant_value, dict):
            founded_func.extend(check_func_in_nested_struct(constant_value, whole_module))
    return founded_func

def get_cfg_instance_of_Load_Module(load_module:Load_Module, whole_module):
    module_list = load_module.module_list
    module_name = ".".join(module_list[:-1])  # match.group(1)
    func_name = module_list[-1]
    callee_cfg = search_cfg_in_whole_module(whole_module, module_name, func_name)
    return callee_cfg

def FilterHandler(candidate_register:Dict, cfg:CFG, whole_module):
    """
        recursively filter out event register for cfg

        simple filter, requirement:
            1. callee name is str
            2. have param, and is not variable
            3. param name is str
        
        candidate_register:
        {
            callee_name: [
                {
                    "module_name": cfg.lua_module.module_name,
                    "param_num": param_num,
                    "param": [
                        (param_idx, param_name)
                    ]
                }
            ]
        }
    """
    # do not generate call graph in root func
    if cfg._func_name != "root_func":
        logger.debug(f"filter out event register for func: {cfg._func_name}")
        for block in cfg.assignment_nodes:
            if isinstance(block, LuaB_Param_Block):
                continue
            for pc, high_instr in block._high_instru.items():
                if isinstance(high_instr, CallInstr):
                    # if pc == 4 :
                    #     set_trace()
                    func_reg_idx = high_instr.target
                    param_num = high_instr.param_num
                    param_begin = high_instr.param_begin
                    if param_num <= 0:
                        # represent no parameter or variable parameter
                        # Register function must have fix number of parameters
                        continue
                    else:
                        callee_name = get_callee_name(cfg, block, pc, func_reg_idx)
                        param_info = list()
                        if callee_name and isinstance(callee_name, str):
                            # register function mush be called through global string.
                            param_idx = 0
                            for param_reg_idx in range(param_begin, param_begin+param_num):
                                param_value = get_param_value_in_filtering_event_handler(cfg, block, pc, param_reg_idx)
                                if param_value and isinstance(param_value, str):
                                    # print(f"{callee_name:<20}, {param_name:<20}")
                                    # if "apmngr_sql_get_group_available_id" in param_value:
                                    #     set_trace()
                                    param_info.append((param_idx, param_value))
                                elif param_value and isinstance(param_value, dict):
                                    # set_trace()
                                    handler_list = check_func_in_nested_struct(param_value, whole_module)
                                    
                                    process_handler_list = list()
                                    for handler in handler_list:
                                        if handler and isinstance(handler, CFG):
                                            # it may be None in the hander list
                                            # and the handler must be CFG instance, it is custom
                                            # if "apmngr_sql_get_group_available_id" in handler._func_name:
                                            #     set_trace()
                                            process_handler_list.append(handler)

                                    # the list represent the handler from nested struct rather than the string
                                    # the handler_list may be an empty list
                                    if process_handler_list:
                                        param_info.append((param_idx, process_handler_list)) 
                                    else:
                                        param_info.append((param_idx, None))
                                else:
                                    param_info.append((param_idx, None))
                                param_idx += 1

                            if callee_name not in candidate_register:
                                candidate_register[callee_name] = list()
                            param_info_dict = {
                                                "module_name": cfg.lua_module.module_name,
                                                "param_num": param_num,
                                                "param": param_info
                                            }
                            candidate_register[callee_name].append(param_info_dict)

    # call graph generation recursively
    for index, sub_cfg in cfg.proto_func.items():
        FilterHandler(candidate_register, sub_cfg, whole_module)


def check_basic_name(name):
    
    partial_match = list()
    complete_match = list()
    
    basic_name_partial = ["nixio", ".gsub", ".foreach", ".getenv", "string.", ".gmatch", ".match", "io.", ".execute", ".exec", ".fork_call", ".fork_exec", "debug", ".encode", ".format", ".split", "uci.cursor", "tonumber", "tostring", "ipairs", "pairs"]
    basic_name_complete = ["require", "assert", "type", "string", "table", "unpack"]
    name_endwith = [".get", ".delete", ".set", ".load", ".foreach", ".delete_all", ".get_all", ".section", ".update", ".write", ".read"]

    partial_match.extend(basic_name_partial)
    complete_match.extend(basic_name_complete)

    if name in complete_match:
        return True
    for basic_name in partial_match:
        if basic_name in name:
            return True
    
    for basic_name in name_endwith:
        if name.endswith(basic_name):
            return True
    
    pattern = r'require\([\'"]([^\'"]+)[\'"]\)$'
    match = re.search(pattern, name)
    if match:
        return True
    
    return False


def check_candidate_register(candidate_register:Dict, whole_module):
    """
        check the candidate event register
    """

    """
        # second filter: filter out the basic func call
        # remove_callee = list()
        # for callee_name, param_info in candidate_register.items():
        #     if check_basic_name(callee_name):
        #         remove_callee.append(callee_name)
        # for callee in remove_callee:
        #     del candidate_register[callee]
        
        # forth filter:
        # set_trace()
    """

    filter_time_register = find_handler_with_register(candidate_register, whole_module)
    
    """
    # set_trace()

    # # fiveth filter:
    # final_register = check_register_by_failure(candidate_register, whole_module, filter_time_register)

    # set_trace()
    # register_name = "register_struct"
    # if check_register_through_nest_struct(register_name, 0, whole_module):
    #     logger.info(f"{register_name}:0 is satisfy the behavior model of register func")
    # set_trace()
    """

    # check by register behavior model
    filter_after_register_behavior = dict()
    fake_register_after_behavior_check = dict()
    for register_name, register_info in filter_time_register.items():
        # set_trace()
        # for info in register_info:
        #     print(f"{register_name:<80}, {info['param_idx']:<2}, {info['type']}")
        #     print(register_name, info["param_idx"], info["type"])
        # set_trace()
        # if "macauth_set_group_by_id" not in register_name and "notifyNmsReportEvent" not in register_name:
        #     continue
        # set_trace()
        # if register_name != "luci.model.controller.dispatch":
        #     continue

        success_info_list = list()
        for info in register_info:
            if info['type'] == "string":
                # print(register_name)
                param_idx = info["param_idx"]
                # if register_name == "luci.dispatcher.call":
                #     set_trace()
                if check_register_through_string(register_name, param_idx, whole_module):
                    logger.debug(f"string:{register_name:<30}:{param_idx} is satisfy the behavior model of register func")
                    success_info_list.append(info)
                else:
                    # set_trace()
                    fake_register_after_behavior_check[f"{register_name}:{param_idx}"] = info["event_handler"]
                    logger.debug(f"string:{register_name:<30}:{param_idx} does not satisfy the behavior model of register func")
            elif info['type'] == "nest_struct":
                param_idx = info["param_idx"]
                if check_register_through_nest_struct(register_name, param_idx, whole_module):
                    success_info_list.append(info)
                    logger.debug(f"nest_struct:{register_name:<30}:{param_idx} is satisfy the behavior model of register func")
                else:
                    fake_register_after_behavior_check[f"{register_name}:{param_idx}"] = info["event_handler"]
                    logger.debug(f"nest_struct:{register_name:<30}:{param_idx} does not satisfy the behavior model of register func")
        if success_info_list:
            filter_after_register_behavior[register_name] = success_info_list
                
    # set_trace()

    # set_trace()
    # register_name = "macauth_set_group_by_id"
    # if check_register_through_string(register_name, 1, whole_module):
    #     logger.info(f"{register_name}:1 is satisfy the behavior model of register func")
    # set_trace()
    # register_test = [
    #     "register_secname_cb",
    #     "register_sectype_cb",
    #     "register_keyword_data",
    #     "register_keyword_action",
    #     "register_keyword_add_data",
    #     "register_keyword_set_data",
    #     "register_keyword_del_data"
    # ]
    
    # for register_name in register_test:
    #     if register_name in ["register_secname_cb", "register_sectype_cb"]:
    #         for param_idx in range(5):
    #             if check_register_through_string(register_name, param_idx, whole_module):
    #                 logger.info(f"{register_name}:{param_idx} is satisfy the behavior model of register func")
    #     else:
    #         for param_idx in range(3):
    #             if check_register_through_string(register_name, param_idx, whole_module):
    #                 logger.info(f"{register_name}:{param_idx} is satisfy the behavior model of register func")

    return filter_after_register_behavior, fake_register_after_behavior_check

def find_handler_with_register(candidate_register, whole_module):
    """
        the param of a register always coresponding to a function in the same module when registering by string
    """
    
    filter_register = dict()
    for register_name, param_info in candidate_register.items():
        # if "jcsUI2uac" in register_name:
        #     set_trace()
        if register_name not in filter_register:
            filter_register[register_name] = dict()
        inconsistend_param_idx = list() # store the param idx which can be either string or nested struct 
        for param in param_info:
            module_name = param["module_name"]
            param_list = param["param"]
            for param_idx, param_name in param_list:
                # if register_name == "register_cli_command" and param_idx == 3:
                #     set_trace()

                if param_idx in inconsistend_param_idx:
                    continue

                if isinstance(param_name, list):
                    if not param_name:
                        continue

                    if param_idx not in filter_register[register_name]:
                        filter_register[register_name][param_idx] = {"total_num":0, "success_num":0, "fail_num":0, "event_handler":list(), "type":"nest_struct"}
                                        
                    # check the isconsistent
                    if filter_register[register_name][param_idx]["type"] != "nest_struct":
                        # that means, the param_idx stores string before
                        if param_idx not in inconsistend_param_idx:
                            inconsistend_param_idx.append(param_idx)

                    filter_register[register_name][param_idx]["total_num"] += len(param_name)
                    filter_register[register_name][param_idx]["success_num"] += len(param_name)
                    filter_register[register_name][param_idx]["event_handler"].extend(param_name)
                elif param_name and isinstance(param_name, str):
                    if param_idx not in filter_register[register_name]:
                        filter_register[register_name][param_idx] = {"total_num":0, "success_num":0, "fail_num":0, "event_handler":list(), "type":"string"}

                    # check the isconsistent
                    if filter_register[register_name][param_idx]["type"] != "string":
                        # that means, the param_idx stores nest_struct before
                        if param_idx not in inconsistend_param_idx:
                            inconsistend_param_idx.append(param_idx)

                    if param_name in whole_module.modules[module_name].global_var:
                        if isinstance(whole_module.modules[module_name].global_var[param_name], CFG):
                            # represent the param name coresponding to a function
                            filter_register[register_name][param_idx]["success_num"] += 1
                            event_handler = whole_module.modules[module_name].global_var[param_name]
                            filter_register[register_name][param_idx]["event_handler"].append(event_handler)
                        else:
                            filter_register[register_name][param_idx]["fail_num"] += 1
                    elif param_name:
                        # represent the param_name exist, but not a function coresponding to it 
                        filter_register[register_name][param_idx]["fail_num"] += 1
                    filter_register[register_name][param_idx]["total_num"] += 1

        for param_idx in inconsistend_param_idx:
            if param_idx in filter_register[register_name]:
                # set_trace()
                del filter_register[register_name][param_idx]
        
        for param_idx, info_dict in filter_register[register_name].items():
            if info_dict["event_handler"]:
                # remove the duplicated handler
                info_dict["event_handler"] = list(set(info_dict["event_handler"]))
        

    # three num record:
    #   total num: all called with param_idx 
    #   success num: called with param_idx, param_name is constant and param_name coresponding to a function
    #   fail num: called with param_idx, param_name is constant, but param_name do not coresponding to a function
    filter_time_register = dict()
    for register_name, register_info in filter_register.items():
        # print(f"register_name: {register_name:<20}")
        for param_idx, param_info in register_info.items():
            # print(f"\tparam_idx: {param_idx:<2}, found_times: {times:<3}")
            # filter success rate less than 0.9
            # if param_info["success_num"] > param_info["fail_num"]*9:
            # filter the param match the func
            if param_info["success_num"] > 0:
                logger.debug(f'register_name: {register_name:<20}, param_idx: {param_idx:<2}, {param_info["total_num"], param_info["success_num"], param_info["fail_num"]}')
                if register_name not in filter_time_register:
                    filter_time_register[register_name] = list()
                filter_info = {"param_idx": param_idx, "event_handler": param_info["event_handler"], "type": param_info["type"]}
                filter_time_register[register_name].append(filter_info)
    # set_trace()
    return filter_time_register


def check_register_by_failure(candidate_register, whole_module, filter_time_register):
    """
        sometimes, multi param of one register may have same names
        we need to check the success rate of matching param name with func name
        filter out the success rate less than 1/2
    """

    final_register = dict()
    register_statistic = dict()
    for register_name, param_info in candidate_register.items():
        if register_name not in filter_time_register:
            continue
        if register_name not in register_statistic:
            register_statistic[register_name] = dict()
        for param in param_info:
            module_name = param["module_name"]
            param_list = param["param"]
            for param_idx, param_name in param_list:
                param_idx_match = False
                for filter_info in filter_time_register[register_name]:
                    if param_idx == filter_info["param_idx"]:
                        param_idx_match = True
                if not param_idx_match:
                    continue
                if param_idx not in register_statistic[register_name]:
                    register_statistic[register_name][param_idx] = {"success":0, "fail":0}
                if param_name in whole_module.modules[module_name].global_var:
                    if isinstance(whole_module.modules[module_name].global_var[param_name], CFG):
                        # represent the param name coresponding to a function
                        register_statistic[register_name][param_idx]["success"] += 1
                        continue
                register_statistic[register_name][param_idx]["fail"] += 1
    
    # set_trace()
    for register_name, statistic_info in register_statistic.items():
        for param_idx, info in statistic_info.items():
            if info["success"] > info["fail"]:
                if register_name not in final_register:
                    final_register[register_name] = list()
                event_handler = None
                for filter_info in filter_time_register[register_name]:
                    if param_idx == filter_info["param_idx"]:
                        event_handler = filter_info["event_handler"]
                final_filter_info = {"param_idx": param_idx, "event_handler": event_handler}
                final_register[register_name].append(final_filter_info)
                logger.debug(f"success: {register_name:<20}, {param_idx}")
            else:
                logger.debug(f"fail:    {register_name:<20}, {param_idx}")
    return final_register

def get_cfg_by_string(func_name_ori:str, whole_module):
    func_name_list = func_name_ori.split(".")
    module_name = ".".join(func_name_list[:-1])
    func_name = func_name_list[-1]
    if func_name_ori == "call":
        module_name = "luci.dispatcher"
        func_name = "call"
    #     set_trace()
    func_found = search_cfg_in_whole_module(whole_module, module_name, func_name)
    if not func_found and len(func_name_list) == 1:
        for sub_module_name, module in whole_module.modules.items():
            for func_cfg in module.root_cfg.proto_func.values():
                if func_cfg._func_name == func_name_ori:
                    # TODO: the call register
                    return func_cfg
    else:
        return func_found

def get_func_to_check_register_behavior(whole_module, func:CFG, collect_func, level=0):
    new_add = list()
    if func in whole_module.callgraph.nodes:
    
        for successor_func in whole_module.callgraph.graph.successors(func):
            """
                do not check the callsite whether has parameters
                because they can transmit data through upvalue
            """
            if successor_func not in collect_func:
                collect_func.append(successor_func)
                new_add.append(successor_func)
    
        if level < 5:
            for successor_func in new_add:
                get_func_to_check_register_behavior(whole_module, successor_func, collect_func, level + 1)

def get_path_list_between_two_func(source_cfg, sink_cfg, whole_module):
    if source_cfg == sink_cfg:
        path_list = list()
        path_list.append([source_cfg])
        return path_list
    if source_cfg in whole_module.callgraph.nodes and sink_cfg in whole_module.callgraph.nodes:
        reverse_cg = whole_module.callgraph.graph.reverse()
        reverse_paths = list(networkx.all_simple_paths(reverse_cg, source=sink_cfg, target=source_cfg, cutoff=7))
        search_paths = [path[::-1] for path in reverse_paths]
        return search_paths


def check_dataflow_with_settable(source_func, param_idx, sink_func, whole_module):
    # get the settable instr list
    settable_instr_list = list()
    for block in sink_func.assignment_nodes:
        if isinstance(block, LuaB_Param_Block):
            continue
        for pc, high_instr in block._high_instru.items():
            if high_instr.instr.name == "SETTABLE":
                """
                    the element idx must be constant string
                    the right value must not be constant string
                """
                # set_trace()
                left_table = high_instr.left_hand_side[0]
                left_table_element = left_table._table_idx
                constant_list = sink_func.constant_propagation.get_constant_before_pc(block, pc)
                element_type, element_value = get_constant_info_of_RK(constant_list, left_table_element)

                if element_type == ConstantType.Constant and isinstance(element_value, str):
                    right_element = high_instr.right_hand_side_variables[0]
                    src_type, src_value = get_constant_info_of_RK(constant_list, right_element)
                    if src_type == ConstantType.Constant and isinstance(src_value, str):
                        continue
                    settable_instr_list.append((block, pc, high_instr))
    if not settable_instr_list:
        return False
    
    # get the path list between source and sink
    path_list = get_path_list_between_two_func(source_func, sink_func, whole_module)
    if not path_list:
        raise Exception("can not find source to sink path")
        return False
    
    # get the souce and sink trigger instance
    source_trigger_instance = None
    for node in source_func.assignment_nodes:
        if isinstance(node, LuaB_Param_Block):
            if node._param_idx == param_idx:
                # taint the instr
                node._param_high_instr.tainted = True
                node._param_high_instr.tainted_idx = [0] # represent that only taint the first left hand of high instr of LuaB_Param_Block

                # generate the trigger instr
                trigger_type = Source_Sink_Type.Source_Param
                trigger_word = source_func._func_name
                source_trigger_instance = Source_Param_Trigger(source_func, trigger_type, trigger_word,\
                                                            param_idx, node._param_high_instr, node)
    
    if not source_trigger_instance:
        # set_trace()
        # raise Exception("can not find source trigger instance")
        # some times, the func with variable parameters
        # and this time, we do not add param block
        return False
    
    for settable_info in settable_instr_list:
        block, pc, high_instr = settable_info
        right_element = high_instr.right_hand_side_variables[0]
        if isinstance(right_element, Register):
            right_value_reg_idx = right_element._idx
            sink_trigger_instance = Sink_Instr_Trigger(sink_func, Source_Sink_Type.Sink_Instr, \
                                                        right_value_reg_idx, pc, high_instr, block)
            
            for link_path in path_list:
                source2sink_result = list()
                taint_propagation_source_to_sink(source_trigger_instance, sink_trigger_instance, link_path, source2sink_result)
                if source2sink_result:
                    return True
    
    return False
                

def check_register_through_string(register_func_name, param_idx, whole_module):
    """
        the candidate register by string will set the string to the table with constant eletemt string

        param_idx: the param idx responding to the func name string in the register_func
    """
    
    register_cfg = get_cfg_by_string(register_func_name, whole_module)
    if not isinstance(register_cfg, CFG):
        return False

    # get the successor func on call graph
    # set_trace()
    check_func_list = [register_cfg]
    get_func_to_check_register_behavior(whole_module, register_cfg, check_func_list)

    for checked_func in check_func_list:
        if check_dataflow_with_settable(register_cfg, param_idx, checked_func, whole_module):
            return True

def check_dataflow_with_call(source_func, param_idx, sink_func, whole_module):
    # get the settable instr list
    # set_trace()
    call_instr_list = list()
    for block in sink_func.assignment_nodes:
        if isinstance(block, LuaB_Param_Block):
            continue
        for pc, high_instr in block._high_instru.items():
            if isinstance(high_instr, CallInstr):
                func_reg_idx = high_instr.target
                callee_name = get_callee_name(sink_func, block, pc, func_reg_idx)
                if not callee_name or (isinstance(callee_name, str) and callee_name.startswith("Param_")):
                    # we need to check if the param can influence the func call target
                    # so, the func name must not be a constant str
                    call_instr_list.append((block, pc, high_instr))
    # set_trace()
    if not call_instr_list:
        return False
    
    # get the path list between source and sink
    path_list = get_path_list_between_two_func(source_func, sink_func, whole_module)
    if not path_list:
        raise Exception("can not find source to sink path")
        return False
    
    # get the souce and sink trigger instance
    source_trigger_instance = None
    for node in source_func.assignment_nodes:
        if isinstance(node, LuaB_Param_Block):
            if node._param_idx == param_idx:
                # taint the instr
                node._param_high_instr.tainted = True
                node._param_high_instr.tainted_idx = [0] # represent that only taint the first left hand of high instr of LuaB_Param_Block

                # generate the trigger instr
                trigger_type = Source_Sink_Type.Source_Param
                trigger_word = source_func._func_name
                source_trigger_instance = Source_Param_Trigger(source_func, trigger_type, trigger_word,\
                                                            param_idx, node._param_high_instr, node)
    
    if not source_trigger_instance:
        return False
    
    # if sink_func._func_name == "func_unknow_0_3_0":
    #     set_trace()
    for call_info in call_instr_list:
        block, pc, high_instr = call_info
        func_reg_idx = high_instr.target

        sink_trigger_instance = Sink_Instr_Trigger(sink_func, Source_Sink_Type.Sink_Instr, \
                                                    func_reg_idx, pc, high_instr, block)
            
        for link_path in path_list:
            source2sink_result = list()
            taint_propagation_source_to_sink(source_trigger_instance, sink_trigger_instance, link_path, source2sink_result)
            if source2sink_result:
                return True
    
    return False

def check_register_through_nest_struct(register_func_name, param_idx, whole_module):
    """
        the candidate register by nest_struct will call the func instance in the struct

        param_idx: the param idx responding to the nest struct containing the func instance
    """
    
    register_cfg = get_cfg_by_string(register_func_name, whole_module)
    if not isinstance(register_cfg, CFG):
        return False

    # get the successor func on call graph
    # set_trace()
    check_func_list = [register_cfg]
    get_func_to_check_register_behavior(whole_module, register_cfg, check_func_list)

    for checked_func in check_func_list:
        # if checked_func._func_name == "func_unknow_0_3_0":
        #     set_trace()
        if check_dataflow_with_call(register_cfg, param_idx, checked_func, whole_module):
            return True    


class Source_Pattern_Func:
    def __init__(self, name):
        self.name = name

class Variable_type(Enum):
    param = "param"
    global_v = "global"

class Source_Pattern_Variable:
    def __init__(self, type, name=None, idx=None):
        self.type = type
        self.name = name
        self.idx = idx

def get_nested_callee_name(callee_name):
    pattern = r'require\([\'"]([^\'"]+)[\'"]\)\.([a-zA-Z_][a-zA-Z0-9_]*)'
    match = re.search(pattern, callee_name)
    if match:
        # situation one:
        #   caller and callee are in the different luac modules
        #   search callee cfg in the whole module
        module_name = match.group(1)
        func_name = match.group(2)
        return f"{module_name}.{func_name}"
    return callee_name

def check_constant_related_to_call(handler_cfg, block, constant_str):
    """
        check if the constant is part of the callee name
    """
    # the call instr is the last instr of block
    last_instr = block._high_instru[block._end]
    if isinstance(last_instr, CallInstr):
        # callee_name = get_concrete_value(handler_cfg, block, block._end, last_instr.target)
        callee_name = get_callee_name(handler_cfg, block, block._end, last_instr.target)
        if callee_name and isinstance(callee_name, str) and constant_str in callee_name:
            return True        
    return False

def if_chain_travel_call(souce_high_instr, sink_high_instr, def_use_list):
    for chain in get_usage_chains(souce_high_instr, sink_high_instr, def_use_list):
        travel_callinstr = False
        for high_instr in chain:
            if isinstance(high_instr, CallInstr):
                travel_callinstr = True
                break
        if not travel_callinstr:
            return False
    return True

def get_source_pattern(register_name, param_info):
    
    param_idx_log = param_info['param_idx']
    handler_list = param_info['event_handler']
    
    result = {
                "param": dict(),
                "global": dict(),
                "func": dict()
            }
    taint_analysis_time = 0
    start_time = datetime.now()
    # TODO: add special process for luci call register function
    for handler_cfg in handler_list:
        # logger.debug(f"analyze cfg: {handler_cfg._func_name}")
        param_secondary_node = dict()
        
        onetime = datetime.now()
        for block in handler_cfg.assignment_nodes:
            if isinstance(block, LuaB_Param_Block):
                param_secondary_node[block._param_idx] = (block._param_high_instr, handler_cfg.get_secondary_nodes(block._param_high_instr))
        twotime = datetime.now()
        taint_analysis_time += (twotime - onetime).total_seconds()

        for block in handler_cfg.assignment_nodes:
            if isinstance(block, LuaB_Param_Block):
                continue
            for pc, high_instr in block._high_instru.items():
                if high_instr.instr.name == "GETTABLE":
                    # begin to check nested access
                    constant_value = get_concrete_value(handler_cfg, block, pc, high_instr.instr.A)
                    # first, check global variable
                    if not constant_value or (isinstance(constant_value, str) and constant_value.startswith("Param_")):
                        for param_idx, (param_high_instr, secondary_nodes) in param_secondary_node.items():
                            # the gettable exclude the func return
                            if high_instr in secondary_nodes and not if_chain_travel_call(param_high_instr, high_instr, handler_cfg.def_use):
                                if param_idx not in result["param"]:
                                    result["param"][param_idx] = 0
                                result["param"][param_idx] += 1
                                # if register_name == "register_keyword_set_data" and \
                                #     param_idx_log == 2 and \
                                #     (param_idx == 1 or param_idx ==2):
                                #     set_trace()
                                #     status = if_chain_travel_call(param_high_instr, high_instr, handler_cfg.def_use)
                                #     print(f"handler_cfg:{handler_cfg._func_name}, pc:{pc}, status:{status}")


    
    end_time = datetime.now()
    total_time = (end_time-start_time).total_seconds()

    # set_trace()
    logger.debug(f"register: {register_name:<20}, param_idx:{param_idx_log}")
    # logger.debug(f"analysis time: tainted_percent:{taint_analysis_time/total_time:.2f} total time:{total_time:.2f}, tainted_analysis_time:{taint_analysis_time:.2f}")
    # set_trace()
    for source_type, info in result.items():
        delete_key = list()
        for key, num in info.items():
            # TODO: need to be consider
            # if num * 2 > len(handler_list):
            #     logger.info(f"type: {source_type:<10}, key:{key}, num:{num}")
            if num <= 2:
                delete_key.append(key)
        for key in delete_key:
            del result[source_type][key]
    return result

         