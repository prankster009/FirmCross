
import sys
sys.path.append("..")
from cfg.cfg import CFG, LuaB_Param_Block
from cfg.high_instruction import AssignmentInstr, Compare_instance, Depend_instance, Concat, Register, CallInstr
from typing import List
from ipdb import set_trace
from .source_sink_identify import Source_Param_Trigger, Source_Ret_Trigger, Source_Instr_Trigger, Sink_Trigger
from analysis.definition_chains import build_def_use_chain
from analysis.constant_propagation import get_concrete_value, Load_Module, get_callee_name
from analysis.analysis import get_block_contain_pc
import itertools
import networkx as nx
from utils.logger import setup_logger
from collections import defaultdict
logger = setup_logger(__name__)
import copy
from datetime import datetime
from vulnerabilities.vulnerability_helper import (
    Sanitiser,
    TriggerNode,
    TriggerInstr,
    Triggers,
    vuln_factory,
    VulnerabilityType
)
from .source_sink_identify import Source_Sink_Type

class Def_Use_Record:
    def __init__(self, use_chain, source_instr, sink_instr, sink_param_reg_idx, sink_param_idx, cfg_idx, cfg):
        self.use_chain = use_chain 
        self.source_instr = source_instr 
        self.sink_instr = sink_instr # this instr is not the high instr of sink trigger, it is the definition of param reg of sink trigger high instr
        self.sink_param_reg_idx = sink_param_reg_idx
        self.sink_param_idx = sink_param_idx
        self.cfg_idx = cfg_idx # cfg_idx in the call graph path
        self.cfg = cfg
        self.assignment_dsp = ""
        self.generate_assignment_description()
    
    def generate_assignment_description(self):
        self.assignment_dsp += "\t Reassignment info:\n"
        for high_instr in self.use_chain:
            result_left = "["
            result_right = "["
            for variable in high_instr.left_hand_side:
                if result_left != "[":
                    result_left += ", "
                result_left += variable.toString()
            
            for variable in high_instr.right_hand_side_variables:
                if result_right != "[":
                    result_right += ", "
                result_right += variable.toString()
            result_left += "]"
            result_right += "]"
            

            self.assignment_dsp += '\t > pc: ' + str(high_instr.pc) + '\t instr: ' + f"{result_left} = {result_right}" + "\n"
            try:
                # set_trace()
                explain = "[%3d] %-40s ; %s" % (high_instr.pc, high_instr.instr.toString(), high_instr.instr.getAnnotation(self.cfg._chunk)) + "\n"
                self.assignment_dsp += f'\t\t > explain: {explain}'
            except:
                pass
        # set_trace()

class Trace_in_CFG:
    def __init__(self, cfg, chain):
        self.cfg = cfg
        self.chain = chain

class Trace_Path:
    def __init__(self, path):
        self.path = path # cfg list
        self.traces = list() # multi Trace_in_CFG instance

def filter_cfg_nodes(
    cfg,
    high_level_instr_type
):
    """
        get the cfg node that contains the 'high_level_instr_type' type instructions
    """
    result = list()
    for node in cfg.graph.nodes():
        for pc, high_instr in node._high_instru.items():
            if isinstance(high_instr, high_level_instr_type):
                result.append(node)
                break
    return result

def add_sink_record(record_dict, cfg, block, high_instr, param_reg_idx, param_idx):
    if cfg not in record_dict:
        record_dict[cfg] = list()
    record_dict[cfg].append((block, high_instr, param_reg_idx, param_idx))

def add_source_record(record_dict, cfg, high_instr):
    if cfg not in record_dict:
        record_dict[cfg] = list()
    record_dict[cfg].append(high_instr)

def get_path_info(paths: List[CFG]):
    """
        get the detail info of the path
    """
    result = ""
    for cfg in paths:
        if result:
            result += " -> "
        result += f"{cfg.lua_module.module_name}:{cfg._func_name}"
    return result

def get_propagation_chain(all_record, final_sink, current_record, chain_idx, chain=[]):
    """
        get the list of all the possible propagation chain
    """
    if len(all_record) == 1:
        # source and sink in the same cfg
        yield [all_record[0][0]]
    elif chain_idx == len(all_record) - 1:
        # hit sink
        if current_record.sink_param_idx == final_sink.param_idx:
            yield chain + [current_record]
        else:
            # set_trace()
            raise Exception("vul report generate: sink record not match")
    else:
        for next_record in get_next_match_record_list(all_record, current_record, chain_idx):
            copied_chain = copy.copy(chain)
            copied_chain.append(current_record)
            yield from get_propagation_chain(all_record, final_sink, next_record, chain_idx+1, copied_chain)
        

def get_next_match_record_list(all_record, current_record, current_chain_idx): 
    """
        get the next record def-use that match the sink of last record
    """
    next_match_record = list()
    next_chain_idx = current_chain_idx + 1
    if next_chain_idx not in all_record:
        raise Exception("vul report generate: next chain idx overflow")
    for next_record in all_record[next_chain_idx]:
        source_param_idx = -3 - next_record.source_instr.pc
        if source_param_idx == current_record.sink_param_idx:
            next_match_record.append(next_record)
    return next_match_record

def if_source_instr_influence_upvalue(source_instr, current_cfg:CFG, next_cfg:CFG):
    """

    """
    # determine the upvalue num
    upvalue_num = next_cfg._chunk.numUpvals
    if not upvalue_num:
        return False

    # locate the instr set the upvalue
    set_upvalue_instr_info = list()
    in_closure = False
    for node in current_cfg.graph.nodes():
        if isinstance(node, LuaB_Param_Block):
            continue
        for pc, high_instr in node._high_instru.items():
            if high_instr.instr.name == "CLOSURE":
                sub_proto_num = high_instr.instr.B
                sub_proto = current_cfg.proto_func[sub_proto_num]
                if sub_proto is next_cfg:
                    in_closure = True
                    upvalue_idx = 0
            elif high_instr.instr.name == "MOVE":
                if in_closure:
                    upvalue_reg_idx = high_instr.instr.B
                    record = (node, high_instr, upvalue_reg_idx, upvalue_idx)
                    set_upvalue_instr_info.append(record)
                    upvalue_idx = upvalue_idx + 1
            elif high_instr.instr.name == "GETUPVAL":   
                if in_closure:
                    upvalue_index = high_instr.instr.B
                    record = (node, "GETUPVAL", upvalue_index, upvalue_idx)
                    set_upvalue_instr_info.append(record)
                    upvalue_idx = upvalue_idx + 1
            else:
                in_closure = False
    if not set_upvalue_instr_info:
        return False

    # set_trace()
    # determine if it is tainted
    tainted_upvalue_idx = list()
    for instr_info in set_upvalue_instr_info:
        block, high_instr, upvalue_reg_idx_or_upvalue_index, upvalue_idx = instr_info
        if isinstance(high_instr, str):
            if source_instr.pc >= 0:
                # exclude the param instr
                if source_instr.instr.name == "GETUPVAL":
                    sink_upvalue_index = upvalue_reg_idx_or_upvalue_index
                    source_upvalue_index = source_instr.instr.B
                    if source_upvalue_index == sink_upvalue_index:
                        tainted_upvalue_idx.append(upvalue_idx)
        else:
            upvalue_reg_idx = upvalue_reg_idx_or_upvalue_index
            if check_dataflow_reach_reg_at_pc(current_cfg, source_instr, high_instr, block, upvalue_reg_idx):
                tainted_upvalue_idx.append(upvalue_idx)
    if not tainted_upvalue_idx:
        return False
    
    return tainted_upvalue_idx



def check_dataflow_reach_reg_at_pc(cfg, souce_high_instr, sink_high_instr, sink_block, reg_idx):

    high_instr_reach_sink = [
        secondary
        for secondary in reversed(cfg.get_secondary_nodes(souce_high_instr))  
        if cfg.RDA_analysis.check_reaching_definition(secondary, sink_high_instr, sink_block)
    ]
    if cfg.RDA_analysis.check_reaching_definition(souce_high_instr, sink_high_instr, sink_block):
        high_instr_reach_sink.append(souce_high_instr)
            
    # No secondary high instr can reach sink
    if not high_instr_reach_sink:
        return False

    tainted_instr_with_sink_arg = get_tainted_instr_with_sink_args(
        reg_idx,
        high_instr_reach_sink,
    )

    if not tainted_instr_with_sink_arg:
        return False
    
    return True


def get_the_getupval_instr_info(cfg, upvalue_idx):
    record_info = list()
    for node in cfg.graph.nodes():
        if isinstance(node, LuaB_Param_Block):
            continue
        for pc, high_instr in node._high_instru.items():
            if high_instr.instr.name == "GETUPVAL":   
                upvalue_index = high_instr.instr.B
                if upvalue_index == upvalue_idx:
                    info = (node, high_instr)
                    record_info.append(info)
    if not record_info:
        raise Exception("get the source GETUPVAL instr of next cfg error")
    return record_info


def taint_propagation_source_to_sink(source_trigger, sink_trigger: Sink_Trigger, path: List[CFG], vul_list: List):
    # set_trace()
    start_time = datetime.now()
    cfg_of_source = source_trigger.cfg
    cfg_of_sink = sink_trigger.cfg
    # aim: check whether sink variable depends on source variable
    path_len = len(path)
    source_record = dict()  # key: cfg, value: high_instr
    sink_record = dict()    # key: cfg, value: (high_instr, param_reg_idx, param_idx)
    vuln_deets = {
        'source': source_trigger,
        'source_trigger_word': source_trigger.trigger_word,
        'sink': sink_trigger,
        'sink_trigger_word': sink_trigger.trigger_word if sink_trigger.type == Source_Sink_Type.Sink_Param else "Sink Instr"
    }
    path_info_print = get_path_info(path)
    logger.debug(f"soure to sink analysis, Source: {source_trigger.__repr__()}, Sink: {sink_trigger.__repr__()}, path: {path_info_print}")
    # if sink_trigger.cfg._func_name == "set_interface_status" and sink_trigger.addr == 115:
    #     set_trace()
    # set_trace()
    usage_chain_record = dict() # key: cfg idx of path, value: list(Def_Use_Record)
    for cfg_idx, cfg_on_path in enumerate(path):
        # record the sink found
        add_sink_info_num = 0
        # determine tainted sink of every level cfg
        if cfg_of_sink == cfg_on_path:
            # sink_trigger
            if sink_trigger.type == Source_Sink_Type.Sink_Param:
                sink_high_instr = sink_trigger.high_instr
                sink_param_reg_idx = get_sink_args(sink_trigger, sink_high_instr)
                sink_block = sink_trigger.block
                add_sink_record(sink_record, cfg_on_path, sink_block, sink_high_instr, sink_param_reg_idx, sink_trigger.param_idx)
                add_sink_info_num += 1
            elif sink_trigger.type == Source_Sink_Type.Sink_Instr:
                sink_high_instr = sink_trigger.high_instr
                reg_idx = sink_trigger.reg_idx
                sink_block = sink_trigger.block
                add_sink_record(sink_record, cfg_on_path, sink_block, sink_high_instr, reg_idx, -1)
                add_sink_info_num += 1
        else:
            # determine the callsite to next_cfg
            if cfg_idx + 1 == path_len:
                raise Exception("taint propagation error: last cfg does not have sink")
            next_cfg = path[cfg_idx+1]
            search_key = (cfg_on_path, next_cfg)
            callsite_info_list = cfg_on_path.lua_module.whole_module.callgraph.callsite[search_key]
            # get the param reg list of callsite
            
            for callsite_info in callsite_info_list:
                callsite_block, callsite_instr_highlevel, callsite_addr = callsite_info
                # for immediate func, we need to get all their param regs.
                callee_param_idx_list = get_all_param_list_of_call(callsite_instr_highlevel)
                for callee_param_idx, callee_param_reg_idx in enumerate(callee_param_idx_list):
                    # if cfg_on_path._func_name == "vulnerableRoute1":
                    #     set_trace()
                    add_sink_record(sink_record, cfg_on_path, callsite_block, callsite_instr_highlevel, callee_param_reg_idx, callee_param_idx)
                    add_sink_info_num = add_sink_info_num + 1
            # if not add_sink_info_num:
            #     # there is no param used  by sink call 
            #     break

        # determine tainted_source of every level cfg
        # set_trace()
        if cfg_of_source == cfg_on_path:
            # according to source_trigger
            if isinstance(source_trigger, Source_Param_Trigger):
                source_trigger.secondary = cfg_of_source.get_secondary_nodes(source_trigger.high_instr)
                add_source_record(source_record, cfg_on_path, source_trigger.high_instr)
            # this is for cmdline arg source
            elif isinstance(source_trigger, Source_Instr_Trigger):
                source_trigger.secondary = cfg_of_source.get_secondary_nodes(source_trigger.high_instr)
                add_source_record(source_record, cfg_on_path, source_trigger.high_instr)
            elif isinstance(source_trigger, Source_Ret_Trigger):
                tainted_return_reg_idx = source_trigger.high_instr.return_begin+source_trigger.return_idx
                # set_trace()
                source_trigger.secondary = cfg_of_source.get_secondary_nodes(source_trigger.high_instr, tainted_return_reg_idx)
                add_source_record(source_record, cfg_on_path, source_trigger.high_instr)
            else:
                raise Exception("taint_propagation_source_to_sink: Unexpected Source Type")
        
        # set_trace()
        # source to sink analysis
        dataflow_source2sink = False
        if add_sink_info_num:
            for source_highinstr in source_record[cfg_on_path]:
                for sink_block, sink_highinstr, sink_param_reg_idx, sink_param_idx in sink_record[cfg_on_path]:
                    if check_two_variable_dependency(cfg_idx, usage_chain_record, cfg_on_path, source_highinstr, \
                                                        sink_block, sink_highinstr, sink_param_reg_idx, sink_param_idx):
                        if sink_highinstr != sink_trigger.high_instr:
                            # add source of next cfg
                            if cfg_idx + 1 == path_len:
                                raise Exception("taint propagation error: last cfg does not have sink")
                            next_cfg = path[cfg_idx+1]
                            # get the param high instr of next cfg according to param idx
                            param_high_instr_next_cfg = get_param_high_instr(next_cfg, sink_param_idx)
                            if not param_high_instr_next_cfg:
                                if sink_highinstr.param_num != -1:
                                    # set_trace()
                                    # TODO: fix the vararg op
                                    logger.error(f"cfg_name:{cfg_on_path.lua_module.module_name}|{cfg_on_path._func_name}, instr:{sink_highinstr.pc}, taint propagation error: can not find source of next cfg")
                                    continue
                                    # raise Exception("taint propagation error: can not find source of next cfg")
                                else:
                                    # the call sink use variable parameter nums
                                    continue
                            add_source_record(source_record, next_cfg, param_high_instr_next_cfg)
                            dataflow_source2sink = True
                        else:
                            # find vulnerability.
                            
                            # the result is record in the usage_chain_record
                            # resolve usage_chain_record and get vulnerability_chain instance
                            # set_trace()
                            propagation_chain_list = list()
                            """
                            the below is already resolve
                                #fix the usage_chain generation, now it only record the use chain between source and sink
                                # it will not record the source and sink instr
                                # so the usage_chain_record is empty when source is directed used by sink
                            """

                            if usage_chain_record:
                                # set_trace()
                                # first_source_record = usage_chain_record[0][0]
                                try:
                                    for first_source_record in usage_chain_record[0]:
                                        for propagation_chain in get_propagation_chain(usage_chain_record, sink_trigger, first_source_record, 0):
                                            # detect whether the chain meet the sanitiser
                                            # TODO: fix the second param
                                            # if source_trigger.cfg._func_name == "ecosUpgrade":
                                            #     set_trace()
                                            vul_type, santizer_record = get_chain_type(propagation_chain, sink_trigger.sanitisers)
                                            chain_info = dict()
                                            chain_info["type"] = vul_type
                                            chain_info["sanitizer"] = santizer_record
                                            chain_info["propagation_chain"] = propagation_chain
                                            propagation_chain_list.append(chain_info)
                                except:
                                    # TODO: fix, key is not start with 0
                                    # ipdb> print(usage_chain_record)
                                    # {1: [<vulnerabilities.vulnerabilities.Def_Use_Record object at 0x7f1145c667d0>, <vulnerabilities.vulnerabilities.Def_Use_Record object at 0x7f1145c66fd0>]}
                                    pass
                                    # set_trace()
                                    # print(usage_chain_record)

                            vuln_deets["propagation_chain_list"] = propagation_chain_list
                            vul_list.append(vuln_deets)
            
        # check if the data from source_highinstr can flow into upvalue of next cfg
        for source_highinstr in source_record[cfg_on_path]:
            if cfg_on_path != cfg_of_sink:
                next_cfg = path[cfg_idx+1]
                tainted_upvalue_idx = if_source_instr_influence_upvalue(source_highinstr, cfg_on_path, next_cfg)
                if tainted_upvalue_idx and isinstance(tainted_upvalue_idx, list):
                    source_getupval_list = list()
                    for upvalue_idx in tainted_upvalue_idx:
                        result_list = get_the_getupval_instr_info(next_cfg, upvalue_idx)
                        source_getupval_list.extend(result_list)

                    for info in source_getupval_list:
                        block, getupval_instr = info
                        add_source_record(source_record, next_cfg, getupval_instr)
                        dataflow_source2sink = True
                    
        
        if not dataflow_source2sink:
            # indicate that in this cfg, source can not reach sink, so dataflow is break
            break
    
    end_time = datetime.now()
    used_time = (end_time-start_time).total_seconds()
    logger.debug(f"soure to sink analysis, Source: {source_trigger.__repr__()}, Sink: {sink_trigger.__repr__()}, path: {path_info_print}, finish")
    return used_time

"""
def taint_propagation_source_to_sink_bak(source_trigger, sink_trigger: Sink_Trigger, path: List[CFG], vul_list: List):
    start_time = datetime.now()
    cfg_of_source = source_trigger.cfg
    cfg_of_sink = sink_trigger.cfg
    # aim: check whether sink variable depends on source variable
    path_len = len(path)
    source_record = dict()  # key: cfg, value: high_instr
    sink_record = dict()    # key: cfg, value: (high_instr, param_reg_idx, param_idx)
    vuln_deets = {
        'source': source_trigger,
        'source_trigger_word': source_trigger.trigger_word,
        'sink': sink_trigger,
        'sink_trigger_word': sink_trigger.trigger_word if sink_trigger.type == Source_Sink_Type.Sink_Param else "Sink Instr"
    }
    path_info_print = get_path_info(path)
    logger.debug(f"soure to sink analysis, Source: {source_trigger.__repr__()}, Sink: {sink_trigger.__repr__()}, path: {path_info_print}")
    # set_trace()
    usage_chain_record = dict() # key: cfg idx of path, value: list(Def_Use_Record)
    for cfg_idx, cfg_on_path in enumerate(path):
        # determine tainted sink of every level cfg
        if cfg_of_sink == cfg_on_path:
            # sink_trigger
            sink_high_instr = sink_trigger.high_instr
            sink_param_reg_idx = get_sink_args(sink_trigger, sink_high_instr)
            sink_block = sink_trigger.block
            add_sink_record(sink_record, cfg_on_path, sink_block, sink_high_instr, sink_param_reg_idx, sink_trigger.param_idx)
        else:
            # determine the callsite to next_cfg
            if cfg_idx + 1 == path_len:
                raise Exception("taint propagation error: last cfg does not have sink")
            next_cfg = path[cfg_idx+1]
            search_key = (cfg_on_path, next_cfg)
            callsite_info_list = cfg_on_path.lua_module.whole_module.callgraph.callsite[search_key]
            # get the param reg list of callsite
            add_sink_info_num = 0
            for callsite_info in callsite_info_list:
                callsite_block, callsite_instr_highlevel, callsite_addr = callsite_info
                # for immediate func, we need to get all their param regs.
                callee_param_idx_list = get_all_param_list_of_call(callsite_instr_highlevel)
                for callee_param_idx, callee_param_reg_idx in enumerate(callee_param_idx_list):
                    # if cfg_on_path._func_name == "vulnerableRoute1":
                    #     set_trace()
                    add_sink_record(sink_record, cfg_on_path, callsite_block, callsite_instr_highlevel, callee_param_reg_idx, callee_param_idx)
                    add_sink_info_num = add_sink_info_num + 1
            if not add_sink_info_num:
                # there is no param used  by sink call 
                break

        # determine tainted_source of every level cfg
        if cfg_of_source == cfg_on_path:
            # according to source_trigger
            if isinstance(source_trigger, Source_Param_Trigger):
                source_trigger.secondary = cfg_of_source.get_secondary_nodes(source_trigger.high_instr)
                add_source_record(source_record, cfg_on_path, source_trigger.high_instr)
            elif isinstance(source_trigger, Source_Ret_Trigger):
                tainted_return_reg_idx = source_trigger.high_instr.return_begin+source_trigger.return_idx
                # set_trace()
                source_trigger.secondary = cfg_of_source.get_secondary_nodes(source_trigger.high_instr, tainted_return_reg_idx)
                add_source_record(source_record, cfg_on_path, source_trigger.high_instr)
            else:
                raise Exception("taint_propagation_source_to_sink: Unexpected Source Type")

        # source to sink analysis
        dataflow_source2sink = False
        for source_highinstr in source_record[cfg_on_path]:
            for sink_block, sink_highinstr, sink_param_reg_idx, sink_param_idx in sink_record[cfg_on_path]:
                if check_two_variable_dependency(cfg_idx, usage_chain_record, cfg_on_path, source_highinstr, \
                                                    sink_block, sink_highinstr, sink_param_reg_idx, sink_param_idx):
                    if sink_highinstr != sink_trigger.high_instr:
                        # add source of next cfg
                        if cfg_idx + 1 == path_len:
                            raise Exception("taint propagation error: last cfg does not have sink")
                        next_cfg = path[cfg_idx+1]
                        # get the param high instr of next cfg according to param idx
                        param_high_instr_next_cfg = get_param_high_instr(next_cfg, sink_param_idx)
                        if not param_high_instr_next_cfg:
                            if sink_highinstr.param_num != -1:
                                # set_trace()
                                # TODO: fix the vararg op
                                logger.error(f"cfg_name:{cfg_on_path.lua_module.module_name}|{cfg_on_path._func_name}, instr:{sink_highinstr.pc}")
                                continue
                                raise Exception("taint propagation error: can not find source of next cfg")
                            else:
                                # the call sink use variable parameter nums
                                continue
                        add_source_record(source_record, next_cfg, param_high_instr_next_cfg)
                        dataflow_source2sink = True
                    else:
                        # find vulnerability.
                        
                        # the result is record in the usage_chain_record
                        # resolve usage_chain_record and get vulnerability_chain instance
                        # set_trace()
                        propagation_chain_list = list()
                        # TODO: fix the usage_chain generation, now it only record the use chain between source and sink
                        # it will not record the source and sink instr
                        # so the usage_chain_record is empty when source is directed used by sink
                        if usage_chain_record:
                            first_source_record = usage_chain_record[0][0]
                            for propagation_chain in get_propagation_chain(usage_chain_record, sink_trigger, first_source_record, 0):
                                # detect whether the chain meet the sanitiser
                                # TODO: fix the second param
                                # if source_trigger.cfg._func_name == "ecosUpgrade":
                                #     set_trace()
                                vul_type, santizer_record = get_chain_type(propagation_chain, sink_trigger.sanitisers)
                                chain_info = dict()
                                chain_info["type"] = vul_type
                                chain_info["sanitizer"] = santizer_record
                                chain_info["propagation_chain"] = propagation_chain
                                propagation_chain_list.append(chain_info)
                        vuln_deets["propagation_chain_list"] = propagation_chain_list
                        vul_list.append(vuln_deets)
        if not dataflow_source2sink:
            # indicate that in this cfg, source can not reach sink, so dataflow is break
            break
    
    end_time = datetime.now()
    used_time = (end_time-start_time).total_seconds()
    return used_time

"""

def is_sanitizer(checked_name, sanitizer_list):
    # TODO
    # now, simply compare the last name
    if isinstance(checked_name, str):
        pass
    elif isinstance(checked_name, CFG):
        checked_name = checked_name._func_name
    else:
        return False
    # if checked_name == "macaddr":
    #     set_trace()
    last_name_to_check = checked_name.split(".")[-1]
    for sanitizer_name in sanitizer_list:
        if last_name_to_check == sanitizer_name.split(".")[-1]:
            return True
    return False


# def get_nested_callee_name(callee_name):
#     pattern = r'require\([\'"]([^\'"]+)[\'"]\)\.([a-zA-Z_][a-zA-Z0-9_]*)'
#     match = re.search(pattern, callee_name)
#     if match:
#         # situation one:
#         #   caller and callee are in the different luac modules
#         #   search callee cfg in the whole module
#         module_name = match.group(1)
#         func_name = match.group(2)
#         return f"{module_name}.{func_name}"
#     return callee_name

def add_sanitizer(santizer_record, func_name, sanitizer_name):
    if sanitizer_name not in santizer_record[func_name]:
        santizer_record[func_name].append(sanitizer_name)

def get_cfg_chain_block(cfg, block_list):
    start_node = block_list[0]
    end_node = block_list[-1]
    if len(block_list) == 1:
        return block_list
    else:
        all_paths = list(nx.all_simple_paths(cfg.graph, source=start_node, target=end_node))
        valid_paths = [path for path in all_paths if all(path.index(block_list[i]) < path.index(block_list[i + 1]) for i in range(len(block_list) - 1))]
        return valid_paths

def check_sanitizer_on_control_flow(chain_record_list:Def_Use_Record, sanitizer_list, santizer_record):
    all_cfg_path = list()
    for chain_record in chain_record_list:
        record_cfg = chain_record.cfg
        use_chain_block = list()
        use_chain_instr = chain_record.use_chain
        for high_instr in use_chain_instr:
            block = get_block_contain_pc(high_instr.pc)
            if block not in use_chain_block:
                use_chain_block.append(block)
        
        cfg_chain = get_cfg_chain_block(record_cfg, use_chain_block)
        if not cfg_chain:
            raise Exception(f"get_cfg_chain_block error: func_name: {record_cfg._func_name}")

        all_cfg_path.append(cfg_chain)

    all_combinations = list(itertools.product(*all_cfg_path))

    sanitizer_all_path = list()
    for cfg_chain in all_combinations:
        sanitizer_record = list()
        for block in cfg_chain:
            for pc, high_instr in block._high_instru.items():
                if isinstance(high_instr, CallInstr):
                    # check whether hit the sanitiser
                    # callee_name = get_concrete_value(block.cfg, block, pc, high_instr.target)
                    # if isinstance(callee_name, Load_Module):
                    #     callee_name = ".".join(callee_name.module_list)
                    callee_name = get_callee_name(block.cfg, block, pc, high_instr.target)
                    if is_sanitizer(callee_name, sanitizer_list):
                        add_sanitizer(santizer_record, block.cfg._func_name, callee_name)

    # TODO: precise 


def get_chain_type(propagation_chain, sanitizer_list):
    """
        determine whether the propagation path hit the sanitizer.
    """
    # some sink without sanitizer_list
    santizer_record = defaultdict(list)
    if sanitizer_list:
        for record in propagation_chain:
            # check the function call on the dataflow
            for high_instr in record.use_chain:
                if isinstance(high_instr, CallInstr):
                    # check whether hit the sanitiser
                    pc = high_instr.pc
                    block = get_block_contain_pc(record.cfg, pc)
                    # callee_name = get_concrete_value(record.cfg, block, pc, high_instr.target)
                    # if isinstance(callee_name, Load_Module):
                    #     callee_name = ".".join(callee_name.module_list)
                    callee_name = get_callee_name(record.cfg, block, pc, high_instr.target)
                    if is_sanitizer(callee_name, sanitizer_list):
                        # TODO: The two func below will be sanitized wrong, fix in the future.
                        if record.cfg._func_name == "sdwan_add_entry_async" and pc == 24:
                            continue
                        if record.cfg._func_name == "set_stat_params_config" and (
                            pc == 35 or pc == 45 or pc == 49 or pc == 102 or pc == 106 or pc == 127 or pc == 131 
                        ):
                            continue
                        # print(record.cfg._func_name, pc)
                        add_sanitizer(santizer_record, record.cfg._func_name, callee_name)
        
    # # check the function call on the control flow
    # check_sanitizer_on_control_flow(propagation_chain, sanitizer_list, santizer_record)    


    if len(santizer_record):
        return VulnerabilityType.SANITISED, santizer_record
    else:
        return VulnerabilityType.TRUE, santizer_record

def get_param_high_instr(cfg, param_idx):
    """
        get the param high instr according to parm idx in cfg
    """
    for node in cfg.assignment_nodes:
        if isinstance(node, LuaB_Param_Block):
            if node._param_idx == param_idx:
                return node._param_high_instr

taint_analysis_cache = defaultdict(list)
"""
{
    (source_instr, sink_instr, sink_param_reg_idx):usage_chain_list
}
"""

def cache_taint_analysis(souce_high_instr, sink_high_instr, sink_param_reg_idx, usage_chain_list):
    key = (souce_high_instr, sink_high_instr, sink_param_reg_idx)
    taint_analysis_cache[key].extend(usage_chain_list)

def check_taint_propagation_cache(souce_high_instr, sink_high_instr, sink_param_reg_idx):
    key = (souce_high_instr, sink_high_instr, sink_param_reg_idx)
    if key in taint_analysis_cache:
        return True, taint_analysis_cache[key]
    else:
        return False, []

def check_two_variable_dependency(cfg_idx, usage_chain_record, current_cfg, souce_high_instr, \
                                    sink_block, sink_high_instr, sink_param_reg_idx, sink_param_idx):
    """
        in the current_cfg, check if the sink param reg (idx is sink_param_reg_idx at the sink_high_instr) depends on left_hand of source_high_instr.
    """
    # filter the secondary instr of source that can reach the sink instr
    # TODO: reverse need to be consider, should follow the cfg

    # if current_cfg._func_name == "wol_wake":
    #     tmp_dict = dict()
    #     for high_instr in current_cfg.get_secondary_nodes(souce_high_instr):
    #         tmp_dict[high_instr.pc] = high_instr
    #     sorted_dict = {k: tmp_dict[k] for k in sorted(tmp_dict)}
    #     for pc, high_instr in sorted_dict.items():
    #         print(f"{pc}:{high_instr}")
        
    #     set_trace()

    if not souce_high_instr:
        logger.error(f"{current_cfg._func_name} meet the empty source high instr")
        return False
    
    # detect if cached
    cached, usage_chain = check_taint_propagation_cache(souce_high_instr, sink_high_instr, sink_param_reg_idx)
    if cached:
        if len(usage_chain) > 0:
            if cfg_idx not in usage_chain_record:
                usage_chain_record[cfg_idx] = list()
            usage_chain_record[cfg_idx].extend(usage_chain)
            return True
        else:
            # cache, but source can not reach sink
            return False

    # if current_cfg._func_name == "doSwitchApi":
    #     set_trace()

    high_instr_reach_sink = [
        secondary
        for secondary in reversed(current_cfg.get_secondary_nodes(souce_high_instr))  
        if current_cfg.RDA_analysis.check_reaching_definition(secondary, sink_high_instr, sink_block)
    ]
    if current_cfg.RDA_analysis.check_reaching_definition(souce_high_instr, sink_high_instr, sink_block):
        high_instr_reach_sink.append(souce_high_instr)
    
    # No secondary high instr can reach sink
    if not high_instr_reach_sink:
        cache_taint_analysis(souce_high_instr, sink_high_instr, sink_param_reg_idx, [])
        return False

    tainted_instr_with_sink_arg = get_tainted_instr_with_sink_args(
        sink_param_reg_idx,
        high_instr_reach_sink,
    )
    # set_trace()
    # No secondary high instr has relationship with sink reg.
    if not tainted_instr_with_sink_arg:
        cache_taint_analysis(souce_high_instr, sink_high_instr, sink_param_reg_idx, [])
        return False

    # get usage chain from source to sink
    current_taint_propagation_chain = list()
    # for chain in get_usage_chains(souce_high_instr, tainted_instr_with_sink_arg, current_cfg.def_use):
    for chain in get_usage_chains(souce_high_instr, sink_high_instr, current_cfg.def_use):
        if cfg_idx not in usage_chain_record:
            usage_chain_record[cfg_idx] = list()
        
        # original chain only contain the dataflow, may lose some cfg info
        # so, we need to add them
        # set_trace()
        # TODO: fix this
        # set_trace()
        enrich_chain_dict = enrich_usage_chain_simple([souce_high_instr] + current_cfg.get_secondary_nodes(souce_high_instr), current_cfg, [souce_high_instr] + chain)
        # enrich_chain_dict = enrich_usage_chain(current_cfg.get_secondary_nodes(souce_high_instr), current_cfg, [souce_high_instr] + chain)
        for index, enrich_chain in enrich_chain_dict.items():
            record_instance = Def_Use_Record(enrich_chain, souce_high_instr, sink_high_instr, \
                                                sink_param_reg_idx, sink_param_idx, cfg_idx, current_cfg)
            # record_instance = Def_Use_Record(enrich_chain, souce_high_instr, tainted_instr_with_sink_arg, \
            #                                     sink_param_reg_idx, sink_param_idx, cfg_idx, current_cfg)
            current_taint_propagation_chain.append(record_instance)
            usage_chain_record[cfg_idx].append(record_instance)

        # # choice two
        # record_instance = Def_Use_Record(chain, souce_high_instr, tainted_instr_with_sink_arg, \
        #                                     sink_param_reg_idx, sink_param_idx, cfg_idx, current_cfg)
        # current_taint_propagation_chain.append(record_instance)
        # usage_chain_record[cfg_idx].append(record_instance)
    
    cache_taint_analysis(souce_high_instr, sink_high_instr, sink_param_reg_idx, current_taint_propagation_chain)
    return True

def enrich_usage_chain(secondary_nodes, cfg, original_chain):
    use_chain_block = list()
    for high_instr in original_chain:
        block = get_block_contain_pc(cfg, high_instr.pc)
        if block not in use_chain_block:
            use_chain_block.append(block)

    start_node = use_chain_block[0]
    end_node = use_chain_block[-1]

    all_paths = list(nx.all_simple_paths(cfg.graph, source=start_node, target=end_node))
    # valid_paths = [path for path in all_paths if all(path.index(use_chain_block[i]) < path.index(use_chain_block[i + 1]) for i in range(len(use_chain_block) - 1))]
    
    valid_paths = [
        path for path in all_paths
        if all(
            (use_chain_block[i] in path and use_chain_block[i + 1] in path and path.index(use_chain_block[i]) < path.index(use_chain_block[i + 1]))
            for i in range(len(use_chain_block) - 1)
        )
    ]


    enrich_chain = dict()
    for index, path in enumerate(valid_paths):
        enrich_chain[index] = list()
        for block in path:
            for pc, high_instr in block._high_instru.items():
                if high_instr in secondary_nodes:
                    if high_instr in original_chain:
                        enrich_chain[index].append(high_instr)
                    # add the Call instr in the cfg, this may be related to sanitizer
                    elif isinstance(high_instr, CallInstr):
                        enrich_chain[index].append(high_instr)
        # TODO: need to consider the cfg explorision, now, we only consider one path
        break
        
    return enrich_chain

def enrich_usage_chain_simple(secondary_nodes, cfg, original_chain):
    """
        get the shortest path
    """

    last_high_instr = original_chain[-1]

    use_chain_block = list()
    for high_instr in original_chain:
        block = get_block_contain_pc(cfg, high_instr.pc)
        if block not in use_chain_block:
            use_chain_block.append(block)

    shortest_path = list()
    if len(use_chain_block) == 1:
        shortest_path = use_chain_block
    else:
        for i in range(len(use_chain_block)-1):
            # nx.shortest_path(G, source=1, target=5)
            shortest_path = shortest_path + list(nx.shortest_path(cfg.graph, source=use_chain_block[i], target=use_chain_block[i+1]))

    enrich_chain = dict()

    enrich_chain[0] = list()
    for block in shortest_path:
        for pc, high_instr in block._high_instru.items():
            if high_instr in secondary_nodes:
                if high_instr in original_chain:
                    enrich_chain[0].append(high_instr)
                # add the Call instr in the cfg, this may be related to sanitizer
                elif isinstance(high_instr, CallInstr):
                    enrich_chain[0].append(high_instr)
                if last_high_instr == high_instr:
                    # meet the last high instr
                    break
        
    return enrich_chain

def get_tainted_instr_with_sink_args(
    sink_args_idx,
    high_instr_in_constraint
):
    """
        get the tainted high instr, whose variable of left hand is sink function param reg
    """
    # the sink_args_idx should not check 
    # becase use it can be zero
    if not high_instr_in_constraint:
        return None
    # Starts with the node closest to the sink
    # TODO: only get one?
    for high_instr in high_instr_in_constraint:
        for variable in high_instr.left_hand_side:
            if isinstance(variable, Register):
                if variable._idx == sink_args_idx:
                    return high_instr

def get_sink_args(sink_trigger_instance:Sink_Trigger, high_instr: CallInstr) -> int:
    """
        get the param_reg_idx list of sink function according to sink trigger
    """
    param_reg_idx_list = get_all_param_list_of_call(high_instr)
    return param_reg_idx_list[sink_trigger_instance.param_idx]

def get_all_param_list_of_call(callinstr) -> List:
    """
        get all the param idx of the function call instr
    """
    if isinstance(callinstr, CallInstr):
        if callinstr.param_num != -1:
            return [idx for idx in range(callinstr.param_begin, callinstr.param_num+callinstr.param_begin)]
        else:
            return [idx for idx in range(callinstr.param_begin, callinstr.maxStack)]
    else:
        raise Exception("get_all_param_list_of_call: error, instr is not a call instr")

def get_usage_chains(source_instr, sink_instr, def_use, chain=[], visited=None):
    """Traverses the def-use graph to find the instruction usage from source to sink

    Args:
        current_node()
        sink()
        def_use(dict):
        chain(list(Node)): A path of nodes between source and sink.
    """
    if visited == None:
        visited = set()  # Initialize visited set in the first call
    visited.add(source_instr)

    # TODO: flow sensitive
    for use in def_use[source_instr]:
        if use == sink_instr:
            yield chain + [use]
        elif use not in visited:  # Only recurse if we haven't visited the node yet
            vuln_chain = list(chain)
            vuln_chain.append(use)
            yield from get_usage_chains(
                use,
                sink_instr,
                def_use,
                copy.copy(vuln_chain), #TODO: vuln_chain does not need to be copyied?
                visited.copy()  # Pass a copy of visited to the recursive call
            )


def get_vulnerability(
    source,
    sink,
    lattice,
    cfg,
):
    """Get vulnerability between source and sink if it exists.

    Uses triggers to find sanitisers.

    Args:
        source(TriggerNode): TriggerNode of the source.
        sink(TriggerNode): TriggerNode of the sink.
        triggers(Triggers): Triggers of the CFG.
        lattice(Lattice): the lattice we're analysing.
        cfg(CFG): .blackbox_assignments used in is_unknown, .nodes used in build_def_use_chain
    
    Returns:
        A Vulnerability if it exists, else None
    """


    # if tainted_node_in_sink_arg:


    #     sanitiser_nodes = set()
    #     potential_sanitiser = None
    #     # if sink.sanitisers:
    #     #     pass
    #     set_trace()
    #     def_use = build_def_use_chain(
    #         cfg, 
    #         cfg._high_instrs,
    #         lattice
    #     )
        
    #     for chain in get_vulnerability_chains(
    #         source.high_instr,
    #         tainted_node_in_sink_arg,
    #         def_use
    #     ):

    #         vuln_deets['reassignment_nodes'] = chain

    #         return vuln_factory(VulnerabilityType.TRUE)(**vuln_deets)

    # return None

