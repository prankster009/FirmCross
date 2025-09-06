import sys
sys.path.append("..")
from enum import Enum
from typing import List
from cfg.cfg import CFG, LuaB_Param_Block, LuaB_Block
from vulnerabilities.trigger_definitions_parser import Source, Sink
from cfg.high_instruction import (
    AssignmentInstr, 
    CallInstr,
    Global,
    Register,
    Concat,
    Upvalue,
    Constant,
    Table,
    Compare_instance,
    Depend_instance
)
from analysis.constant_propagation import get_concrete_value, Load_Module, get_callee_name
from ipdb import set_trace
from utils.logger import setup_logger
import re
logger = setup_logger(__name__)


class Source_Sink_Type(Enum):
    Source_Param = "Source_Param"
    Source_Ret   = "Source_Ret"
    Source_Instr = "Source_Instr"
    Sink_Param   = "Sink_Param"
    Sink_Instr   = "Sink_Instr"
    Sink_Lua_Table_Func = "Sink_Lua_Table_Func"

class Trigger:
    def __init__(self, type):
        self.type = type

class Source_Param_Trigger(Trigger):
    def __init__(self, cfg, type, trigger_word, param_idx, high_instr, block):
        super().__init__(type)
        self.cfg = cfg
        self.trigger_word = trigger_word
        self.param_idx = param_idx
        self.high_instr = high_instr
        self.secondary = None
        self.block = block

    def __repr__(self):
        return (
            '\nSource Trigger\n'
            'module name: {}\n'
            'func name: {}\n'
            'type: {}\n'
            'trigger_word: {}\n'
            'param_idx: {}\n'.format(
                self.cfg.lua_module.module_name,
                self.cfg._func_name,
                self.type,
                self.trigger_word,
                self.param_idx
            )
        )

class Source_Ret_Trigger(Trigger):
    def __init__(self, cfg, type, trigger_word, return_idx, addr, high_instr, block):
        super().__init__(type)
        self.cfg = cfg
        self.trigger_word = trigger_word 
        self.return_idx = return_idx # the idx of tainted return value
        self.addr = addr # the instr num calling source
        self.high_instr = high_instr
        self.secondary = None
        self.block = block

    def __repr__(self):
        return (
            '\nSource Trigger\n'
            'module name: {}\n'
            'func name: {}\n'
            'type: {}\n'
            'trigger_word: {}\n'
            'addr: {}\n'.format(
                self.cfg.lua_module.module_name,
                self.cfg._func_name,
                self.type,
                self.trigger_word,
                self.addr
            )
        )

class Source_Instr_Trigger(Trigger):
    def __init__(self, cfg, type, high_instr, block, trigger_word="Source_Instr"):
        super().__init__(type)
        self.cfg = cfg
        self.high_instr = high_instr
        self.block = block
        self.secondary = None
        self.trigger_word = trigger_word

    def __repr__(self):
        return (
            '\nSource Trigger\n'
            'module name: {}\n'
            'func name: {}\n'
            'type: {}\n'
            'trigger_word: {}\n'.format(
                self.cfg.lua_module.module_name,
                self.cfg._func_name,
                self.type,
                self.trigger_word,
            )
        )

class Sink_Instr_Trigger(Trigger):
    def __init__(self, cfg, type, reg_idx, addr, high_instr, block, sanitisers=None):
        super().__init__(type)
        self.cfg = cfg
        self.reg_idx = reg_idx
        self.addr = addr # the instr num calling sink
        self.high_instr = high_instr
        self.block = block
        self.sanitisers = sanitisers
        self.param_idx = -1 # use for matching the use chain, function get_propagation_chain

    def __repr__(self):
        return (
            '\nSink Trigger\n'
            'module name: {}\n'
            'func name: {}\n'
            'type: {}\n'
            'trigger_word: Sink Instr\n'
            'reg_idx: {}\n'
            'addr: {}\n'.format(
                self.cfg.lua_module.module_name,
                self.cfg._func_name,
                self.type,
                self.reg_idx,
                self.addr
            )
        )

class Sink_Trigger_Lua_Table_Func(Trigger):
    def __init__(self, cfg, type, lib_name, trigger_word, param_idx, addr, high_instr, block, sanitisers):
        super().__init__(type)
        self.cfg = cfg
        self.lib_name = lib_name
        self.trigger_word = trigger_word
        self.param_idx = param_idx
        self.addr = addr # the instr num calling sink
        self.high_instr = high_instr
        self.block = block
        self.sanitisers = sanitisers
    
    def __repr__(self):
        return (
            '\nSink Trigger\n'
            'module name: {}\n'
            'func name: {}\n'
            'type: {}\n'
            'lib_name: {}\n'
            'trigger_word: {}\n'
            'param_idx: {}\n'
            'addr: {}\n'.format(
                self.cfg.lua_module.module_name,
                self.cfg._func_name,
                self.type,
                self.lib_name,
                self.trigger_word,
                self.param_idx,
                self.addr
            )
        )

class Sink_Trigger(Trigger):
    def __init__(self, cfg, type, trigger_word, param_idx, addr, high_instr, block, sanitisers):
        super().__init__(type)
        self.cfg = cfg
        self.trigger_word = trigger_word
        self.param_idx = param_idx
        self.addr = addr # the instr num calling sink
        self.high_instr = high_instr
        self.block = block
        self.sanitisers = sanitisers
    
    def __repr__(self):
        return (
            '\nSink Trigger\n'
            'module name: {}\n'
            'func name: {}\n'
            'type: {}\n'
            'trigger_word: {}\n'
            'param_idx: {}\n'
            'addr: {}\n'.format(
                self.cfg.lua_module.module_name,
                self.cfg._func_name,
                self.type,
                self.trigger_word,
                self.param_idx,
                self.addr
            )
        )

def get_CmdlineSource_triggers(cfg:CFG, cfg_nodes):
    source_trigger_list = list()
    cmdline_instr_infos = get_cmdline_instr_lists(cfg, cfg_nodes)
    for single_cmdline_info in cmdline_instr_infos:
        block, pc, reg_idx_to_store_cmdline, high_instr, commandline_idx = single_cmdline_info
        trigger_type = Source_Sink_Type.Source_Instr
        trigger_word = f"No.{int(commandline_idx)} command line arg"
        logger.debug(f"find source in {cfg._func_name}, trigger_word: {trigger_word}, type: {trigger_type}")
        trigger_instance = Source_Instr_Trigger(cfg, trigger_type, high_instr, block, trigger_word)
        source_trigger_list.append(trigger_instance)
    return source_trigger_list


def get_source_triggers(cfg:CFG, cfg_nodes, sources_definition: List[Source]):
    """
        tainted high_level_instr according to sources, and return the Trigger instr list
    """
    
    source_trigger_list = list()
    callee_info = get_callee_from_cfgnode(cfg, cfg_nodes)
    for source_instance in sources_definition:
        if source_instance.type == "param":
            # tainted the function param at the function entry
            if source_instance.trigger_word == cfg._func_name:
                for node in cfg_nodes:
                    if isinstance(node, LuaB_Param_Block):
                        if node._param_idx == source_instance.idx:
                            # taint the instr
                            node._param_high_instr.tainted = True
                            node._param_high_instr.tainted_idx = [0] # represent that only taint the first left hand of high instr of LuaB_Param_Block

                            # generate the trigger instr
                            trigger_type = Source_Sink_Type.Source_Param
                            trigger_word = source_instance.trigger_word
                            logger.debug(f'find source in {cfg._func_name}, trigger_word: {trigger_word}, type: {trigger_type}, idx:{source_instance.idx}')
                            trigger_instance = Source_Param_Trigger(cfg, trigger_type, trigger_word,\
                                                                     source_instance.idx, node._param_high_instr, node)
                            source_trigger_list.append(trigger_instance)
        elif source_instance.type == "ret":
            for call_instance in callee_info:
                callee_name, block, pc, reg_idx, high_instr = call_instance
                if Compare_TriggerWord_with_Callee(source_instance.trigger_word, callee_name):
                    trigger_type = Source_Sink_Type.Source_Ret
                    return_idx = source_instance.idx # represent the return idx of source func
                    trigger_word = callee_name
                    logger.debug(f"find source in {cfg._func_name}, trigger_word: {trigger_word}, type: {trigger_type}, idx: {return_idx}")
                    trigger_instance = Source_Ret_Trigger(cfg, trigger_type, trigger_word, return_idx, pc, high_instr, block)
                    source_trigger_list.append(trigger_instance)
        # else:
        #     set_trace()
        #     raise Exception("Unexpected source definition")
    # set_trace()
    cmdline_source_trigger_list = get_CmdlineSource_triggers(cfg, cfg_nodes)
    source_trigger_list.extend(cmdline_source_trigger_list)

    return source_trigger_list

# def do_CmdlineSource_identify(cfg:CFG, source_list, arg_idxs):
#     """
#         in cfg, identify source from command line and store them in source_list
#     """
#     sources_triggers = get_CmdlineSource_triggers(cfg, cfg.assignment_nodes, arg_idxs)
#     source_list.extend(sources_triggers)
#     for index, sub_cfg in cfg.proto_func.items():
#         do_CmdlineSource_identify(sub_cfg, source_list, arg_idxs)

def do_source_identify_according_to_pyt(cfg:CFG, source_definition_list: List[Source], source_list):
    """
        in cfg, identify source and store them in source_list according to source_definition_list
    """
    # TODO: param_ret is not assignmentInstr, fix in the future
    sources_triggers = get_source_triggers(cfg, cfg.assignment_nodes, source_definition_list)
    source_list.extend(sources_triggers)
    for index, sub_cfg in cfg.proto_func.items():
        do_source_identify_according_to_pyt(sub_cfg, source_definition_list, source_list)

def Compare_TriggerWord_with_Callee(trigger_word, callee_name):
    """
        trigger_word: e.g. io.popen, os.execute, luci.sys.fork_call
        callee_name: e.g. io.popen, require("luci.sys").fork_call
    """
    if trigger_word.startswith("*."):
        # e.g. *.fork_call
        # only compare the last name
        # set_trace()
        trigger_last_name = trigger_word.split(".")[-1]
        callee_last_name = callee_name.split(".")[-1]
        if callee_last_name == trigger_last_name:
            return True
        else:
            return False

    if trigger_word == callee_name:
        """
            e.g. io.popen == io.popen
            luci.sys.fork_call
        """
        return True
    
    return False

def get_cmdline_instr_lists(cfg, cfg_nodes:List[LuaB_Block]):
    cmdline_instrs = list()
    for block in cfg_nodes:
        if isinstance(block, LuaB_Param_Block):
            continue
        for pc, high_instr in block._high_instru.items():
            if high_instr.instr.name == "GETTABLE":
                right_variable = high_instr.right_hand_side_variables[0]
                table_reg = right_variable._table_reg
                element_idx = right_variable._table_idx
                
                # check table reg value
                table_reg_idx = table_reg._idx
                is_cmdline_arg = False
                constant_value = get_concrete_value(cfg, block, pc, table_reg_idx)
                if isinstance(constant_value, str) and constant_value == "arg":
                    is_cmdline_arg = True
                
                if is_cmdline_arg:
                    # judget table_idx value
                    if isinstance(element_idx, Constant):
                        if element_idx._type == 3: #number
                            reg_idx_to_store_cmdline = high_instr.instr.A
                            cmdline_instrs.append([block, pc, reg_idx_to_store_cmdline, high_instr, element_idx._data])
    
    return cmdline_instrs

def get_callee_from_cfgnode(cfg, cfg_nodes:List[LuaB_Block]):
    # if cfg._func_name == "wol_wake":
    #     set_trace()
    call_info = list()
    for block in cfg_nodes:
        if isinstance(block, LuaB_Param_Block):
            continue
        for pc, high_instr in block._high_instru.items():
            # if high_instr.instr.name == "CALL":
            if isinstance(high_instr, CallInstr):
                reg_idx = high_instr.instr.A
                # callee_name = get_concrete_value(cfg, block, pc, reg_idx)
                callee_name = get_callee_name(cfg, block, pc, reg_idx)
                if callee_name:
                    # some callee may be CFG, which are local funcs. we need not to consider that situation .
                    if isinstance(callee_name, str):
                        call_info.append([callee_name, block, pc, reg_idx, high_instr])
                    # elif isinstance(callee_name, Load_Module):
                    #     callee_name_combine = ".".join(callee_name.module_list)
                    #     call_info.append([callee_name_combine, block, pc, reg_idx, high_instr])
                # else:
                #     raise ValueError(f"callee_name not found, pc={pc}")
    return call_info

def is_param_constant(cfg, block, pc, call_instr, param_idx):
    """
        check whether the param reg of the callee is a constant
    """
    # TODO
    # fail: because the constant of call instr return value is not accurate
    # if cfg._func_name == "sdwan_add_entry_async" and pc == 61:
    #     set_trace()
    param_begin = call_instr.param_begin
    param_num = call_instr.param_num
    if param_idx + 1 <= param_num or param_num == -1:
        param_reg_idx = param_begin + param_idx
    else:
        # the param idx in sink trigger can not found in this call instr
        return True
    
    param_name = get_concrete_value(cfg, block, pc, param_reg_idx)
    if param_name and not isinstance(param_name, Load_Module):
        return True
    else:
        return False

def get_sink_triggers(cfg, cfg_nodes, sinks_definition: List[Sink]):
    # if cfg._func_name == "sdwan_add_entry_async":
    #     set_trace()
    # first, travel the call op and get call info
    sink_trigger_list = list()
    callee_info = get_callee_from_cfgnode(cfg, cfg_nodes)
    
    # second, get the accurate sink info according to sinks
    for sink_instance in sinks_definition:
        # set_trace()
        for call_instance in callee_info:
            callee_name, block, pc, reg_idx, high_instr = call_instance
            # if cfg._func_name == "sdwan_add_entry_async" and pc ==78 and "fork_call" in sink_instance.trigger_word:
            #     set_trace()
            # if "popen" in sink_instance.trigger_word and "popen" in callee_name:
            #     set_trace()
            
            if Compare_TriggerWord_with_Callee(sink_instance.trigger_word, callee_name):
                trigger_type = Source_Sink_Type.Sink_Param
                param_idx = sink_instance.idx # represent the param idx of sink func
                
                # check whether the param of sink func is constant
                # TODO: this is a error: when the param reg is a global variable, it will wrongly treat it as constant and
                # not treat it as a sink: see example, /home/iot_2204/lua_analysis/Luabyte_Taint_large_test/test_case/cmdline_test/cmdline.luac
                param_reg_idx = high_instr.param_begin + param_idx
                param_value = get_concrete_value(cfg, block, pc, param_reg_idx)
                if param_value and not isinstance(param_value, Load_Module):
                    if isinstance(param_value, str) and param_value.startswith("arg."):
                        # TODO: fix the situation in the constant analysis period
                        pass
                    else:
                        continue

                trigger_word = callee_name
                logger.debug(f"find sink in {cfg._func_name}, trigger_word: {trigger_word}, type: {trigger_type}, idx: {param_idx}")
                # set_trace()
                trigger_instance = Sink_Trigger(cfg, trigger_type, trigger_word, param_idx, pc, high_instr, block, sink_instance.sanitisers)
                sink_trigger_list.append(trigger_instance)
    
    return sink_trigger_list


def do_sink_identify(cfg:CFG, sink_definition_list: List[Sink], sink_list):
    """
        in cfg, identify sink and store them in sink_list according to sink_definition_list
    """
    sinks_triggers = get_sink_triggers(cfg, cfg.assignment_nodes, sink_definition_list)
    sink_list.extend(sinks_triggers)
    for index, sub_cfg in cfg.proto_func.items():
        do_sink_identify(sub_cfg, sink_definition_list, sink_list)


def get_lua_table_sink_triggers(cfg, cfg_nodes, lua_table_info_list):
    sink_trigger_list = list()
    callee_info = get_callee_from_cfgnode(cfg, cfg_nodes)
    # if cfg._func_name == "fetch" and "dev_config" in cfg.lua_module.module_name:
    #     set_trace()
    
    # second, get the accurate sink info according to sinks
    for lib_name, func_name in lua_table_info_list:
        for call_instance in callee_info:
            callee_name, block, pc, reg_idx, high_instr = call_instance
            if Compare_TriggerWord_with_Callee(f"{lib_name.replace('.so', '')}.{func_name}", callee_name):
                trigger_type = Source_Sink_Type.Sink_Lua_Table_Func
                # all the param of lua table func are sinks
                if high_instr.param_num != -1:
                    for param_reg_idx in range(high_instr.param_begin, high_instr.param_begin+high_instr.param_num):
                        param_value = get_concrete_value(cfg, block, pc, param_reg_idx)
                        if param_value and not isinstance(param_value, Load_Module):
                            continue
                        param_idx = param_reg_idx - high_instr.param_begin
                        trigger_word = func_name
                        logger.debug(f"find sink in {cfg._func_name}, trigger_word: {trigger_word}, type: {trigger_type}, idx: {param_idx}")
                        trigger_instance = Sink_Trigger_Lua_Table_Func(cfg, trigger_type, lib_name, trigger_word, param_idx, pc, high_instr, block, None)
                        sink_trigger_list.append(trigger_instance)
                else:
                    # multi param
                    for param_reg_idx in range(high_instr.param_begin, high_instr.maxStack):
                        param_value = get_concrete_value(cfg, block, pc, param_reg_idx)
                        if param_value and not isinstance(param_value, Load_Module):
                            continue
                        param_idx = param_reg_idx - high_instr.param_begin
                        trigger_word = func_name
                        logger.debug(f"find sink in {cfg._func_name}, trigger_word: {trigger_word}, type: {trigger_type}, idx: {param_idx}")
                        trigger_instance = Sink_Trigger_Lua_Table_Func(cfg, trigger_type, lib_name, trigger_word, param_idx, pc, high_instr, block, None)
                        sink_trigger_list.append(trigger_instance)
    
    return sink_trigger_list



def do_lua_table_sink_identify(cfg:CFG, lua_table_info_list, sink_list):
    sinks_triggers = get_lua_table_sink_triggers(cfg, cfg.assignment_nodes, lua_table_info_list)
    sink_list.extend(sinks_triggers)
    for index, sub_cfg in cfg.proto_func.items():
        do_lua_table_sink_identify(sub_cfg, lua_table_info_list, sink_list)

