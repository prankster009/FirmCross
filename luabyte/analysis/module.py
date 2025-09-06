'''
    one module represent a luac file
'''
import os
import time
import sys
import traceback
import json
sys.path.append("..")
from formatters import text
from collections import defaultdict
from cfg.lundump import LuaUndump
from cfg.cfg import CFG, generate_cfg_recursive, LuaB_Param_Block
from cfg.high_instruction import Register
from cfg.cg import CallGraph, CallGraphGeneration
from .reaching_definitions import do_RDA_analysis_recursively
from .constant_propagation import ConstantPropagation, get_concrete_value, Load_Module, get_string_from_format
from vulnerabilities.source_sink_identify import do_source_identify_according_to_pyt, do_sink_identify, do_lua_table_sink_identify
from vulnerabilities.trigger_definitions_parser import parse
from vulnerabilities.vulnerabilities import taint_propagation_source_to_sink
from vulnerabilities.source_sink_identify import Source_Param_Trigger, Source_Sink_Type, Source_Ret_Trigger, Sink_Trigger_Lua_Table_Func, Sink_Trigger
import networkx
from datetime import datetime
import concurrent.futures
from .multi_thread import run_with_timeout
from vulnerabilities.vulnerability_helper import (
    Sanitiser,
    TriggerNode,
    TriggerInstr,
    Triggers,
    vuln_factory,
    Vulnerability,
    VulnerabilityType
)
from .analysis import get_block_contain_pc, determine_ruijie_fw, extract_values
from utils.logger import setup_logger, init_logger_path
from .filter_handler_source import FilterHandler, check_candidate_register, get_source_pattern, Source_Identify
from typing import List, Dict, Tuple, Optional
from ipdb import set_trace

logger = setup_logger(__name__)
# print(logger.__dict__)
# logger = setup_logger(__name__, log_to_file=False, log_filename='LuabyteTaint_module.log', level=0)

def is_lua_bytecode(filename):
    # TODO: fix
    with open(filename, 'rb') as f:
        header = f.read(4)  # Read the first 4 bytes
        
        # Check if it matches Lua's bytecode magic number for Lua 5.1, 5.2, 5.3
        if header == b'\x1b\x4c\x75\x61':  # Lua magic number for bytecode
            return True
        
        # If no magic number is found, assume it is source code
        return False

time_of_taint_propagation = 0

class Whole_Module:
    def __init__(self, fw_path, output_dir="./", resolve_source=True, is_vul_discover=True, debug = False, sources_and_sinks_definition = None, timeout=300):
        self.search_path = fw_path # resolve all luac file under the path
        logger.info(f"squashfs path: {self.search_path}")
        self.output_dir = output_dir
        self.debug = debug
        self.timeout = timeout
        if sources_and_sinks_definition == None:
            file_dir = os.path.dirname(os.path.abspath(__file__))
            default_pyt = os.path.join(file_dir, "../vulnerability_definitions/default.pyt")
            self.sources_and_sinks_definition = default_pyt
        else:
            self.sources_and_sinks_definition = sources_and_sinks_definition

        self.modules = dict()
        self.parse_module()
        # filter out the candidate event handler
        """
            self.final_register format:
                {
                    register_name: [
                                    {
                                        "param_idx": param_idx,
                                        "event_handler": event_handler --> List[CFG]
                                    }
                                    ]
                }
        """
        self.resolve_source = resolve_source # Bool.
        self.final_register = dict() 
        self.fake_register = list()
        self.source_identify = defaultdict(list)
        self.source_pattern = dict() # {register:{register_idx, source_type}}
        self.callgraph = CallGraph()
        self.generate_callgraph()
        self.do_source_identify()
        if not is_vul_discover:
            return 
        
        """
        # for key,value in self.modules.items():
        #     if "access_ctl" in key:
        #         print(key)
        #         access_ctl = self.modules[key]
        #         set_trace()
        #         for index, cfg in access_ctl.root_cfg.proto_func.items():
        #             if cfg._func_name == "acl_inner_get_rule":
        #                 set_trace()
        #                 print(123) #cfg._chunk
        """

        # source and sink identify
        self.trigger_definition = None
        self.parse_trigger_definition()
        self.source = list()
        self.sink = list()
        self.high_level_source = dict() # Merge the source of the same cfg
        self.high_level_sink = dict() # Merge the sink of the same cfg
        self.idendify_source_sink()
        
        # call graph search
        self.cg_search_result = dict() # the info of call graph search result according to source and sink
        self.get_edge_SourceToSink()

        """
            # num = 0 
            # for key, paths in self.cg_search_result.items():
            #     source_cfg = key[0]
            #     sink_cfg = key[1]
            #     source_trigger_num = len(self.high_level_source[source_cfg])
            #     sink_trigger_num = len(self.high_level_sink[sink_cfg])
            #     num += len(paths) * source_trigger_num * sink_trigger_num
            # print(num)
        """
        # set_trace()
        # vulnerability identify
        self.vulnerability = list()
        self.vulnerability_instance_list = list()
        self.vulnerability_discovery()
        # set_trace()
        # generate vulnerability report 
        # print(f"vul num: {len(self.vulnerability)}")
        logger.info(f"vul num: {len(self.vulnerability)}")
        self.generate_report()

        # get IPC candidate
        self.identify_candidate_program_IPC()

    def do_source_identify(self):
        try:
            if self.resolve_source:
                logger.info("begin to resolve source by register and handler")
                self.filter_out_event_register()
                self.get_source_pattern()
                self.save_source_info()
            else:
                # TODO: read from file
                pass
        except Exception as e:
            error_info = traceback.format_exc()
            logger.error(f"do_source_identify error, msg:{str(error_info)}")

    def save_source_info(self):
        # set_trace()
        logger.debug("save source identify info")
        result_path = os.path.join(self.output_dir, "source_identify")
        if not os.path.exists(result_path):
            os.makedirs(result_path)
       
        # record info about source identify

        # record fake register
        fake_register_record = dict()
        for register_key, fake_handler_list in self.fake_register.items():         
            event_handler_name = list()
            for handler in fake_handler_list:
                module_name = handler.lua_module.module_name
                func_name = handler._func_name
                handler_name = f"{module_name}:{func_name}"
                event_handler_name.append(handler_name)            
            fake_register_record[register_key] = event_handler_name

        with open(os.path.join(result_path, "fake_register"), "w") as f:
            json.dump(fake_register_record, f, indent=4)

        
        # record real register
        with open(os.path.join(result_path, "real_register"), "w") as f:
            for register_name, register_info in self.final_register.items():
                for info in register_info:
                    param_idx = info['param_idx']
                    f.write(f"{register_name}:{param_idx}\n")
            f.write("\n")
        
        # record event handler
        event_handler = defaultdict(int)
        for register_name, Source_Identify_list in self.source_identify.items():
            for source_identify in Source_Identify_list:
                key = f"{register_name}:{source_identify.register_param_idx}"
                
                value = dict()
                value["param"] = list(source_identify.nested_access["param"].keys())
                
                event_handler_name = list()
                for handler in source_identify.event_handler:
                    module_name = handler.lua_module.module_name
                    func_name = handler._func_name
                    handler_name = f"{module_name}:{func_name}"
                    event_handler_name.append(handler_name)
                value["handler"] = event_handler_name
                
                event_handler[key] = value
        
        with open(os.path.join(result_path, "event_handler"),'w') as f:
            json.dump(event_handler, f, indent=4)


    def filter_out_event_register(self):
        logger.info("filter out candidate event register")
        candidate_event_register = dict()
        
        for module_name, module in self.modules.items():
            module.filter_out_event_register(candidate_event_register, self)
        # set_trace()
        logger.info("analyze candidate event register")
        self.final_register, self.fake_register = check_candidate_register(candidate_event_register, self)

        for register_name, register_info in self.final_register.items():
            for info in register_info:
                logger.debug(f"{register_name:<20}, {info['param_idx']:<3}, {len(info['event_handler']):<4}")

    def get_source_pattern(self):
        logger.info("get the source pattern")
        # set_trace()
        for register_name, register_info in self.final_register.items():
            for info in register_info:
                param_idx = info['param_idx']
                logger.debug(f"register: {register_name:<20}, param_idx:{param_idx}")
                event_handler_list = info['event_handler']
                nested_access = get_source_pattern(register_name, info)
                register_instance = Source_Identify(register_name, param_idx, nested_access, event_handler_list)
                self.source_identify[register_name].append(register_instance)
        # set_trace()

    def generate_report(self):
        logger.info("generate vulnerability report")
        for vul_deets in self.vulnerability:
            vul_instance = Vulnerability(**vul_deets)
            # if vul_instance.source.cfg._func_name == "startPortScan":
            #     set_trace()
            self.vulnerability_instance_list.append(vul_instance)

        # set_trace()
        if self.vulnerability_instance_list:
            # text.report(vulnerability_instance_list, sys.stdout, True)
            # text.report2(vulnerability_instance_list)
            text.report3(self.vulnerability_instance_list, self.output_dir, sanitised=False)
        
        # set_trace()
    
    def identify_candidate_program_IPC(self):
        # set_trace()
        for vul in self.vulnerability_instance_list:
            # set_trace()
            try:
                reverse_record_chains = vul.propagation_chain_list[0]["propagation_chain"][::-1]
                cmd = self.identify_candidate_program_IPC_for_one_vul(reverse_record_chains)
                vul.cmd = cmd
            except:
                vul.cmd = ""
        
        lua_to_c_dir = os.path.join(self.output_dir, "Lua_to_C")
        if not os.path.exists(lua_to_c_dir):
            os.mkdir(lua_to_c_dir)
        IPC_path = os.path.join(lua_to_c_dir, "IPC")
        with open(IPC_path, "w+") as f:
            for vul in self.vulnerability_instance_list:
                if vul.cmd:
                    cmd_bin = vul.cmd.split(" ")[0]
                    cmd_bin = cmd_bin.replace("TOP", "")
                    f.write(f"cmd_bin: {cmd_bin:<20}, full_cmd: {vul.cmd}\n")

    def identify_candidate_program_IPC_for_one_vul(self, reverse_record_chains):
        # just only consider IPC by command execution
        for record in reverse_record_chains:
            reverse_chain = record.use_chain[::-1]
            current_cfg = record.cfg

            for i, used_instr in enumerate(reverse_chain):
                pc = used_instr.pc
                block = get_block_contain_pc(current_cfg, pc)
                if not block:
                    continue
                # CONCAT must be use current high instr to check
                # e.g. [08] concat     1   1   2    ; R1 := R1..R2
                # the R1 left is not equal to R1 right
                if used_instr.instr.name == "CONCAT":
                    right_concat = used_instr.right_hand_side_variables[0]
                    if right_concat._data:
                        concat_value = ""
                        for reg in right_concat._data:
                            src_reg_idx = reg._idx
                            constant_value = get_concrete_value(current_cfg, block, pc, src_reg_idx)
                            if isinstance(constant_value, Load_Module):
                                callee_name = ".".join(constant_value.module_list)
                                if "format" in callee_name:
                                    concat_value += get_string_from_format(reverse_record_chains)
                                else:
                                    concat_value += "TOP"
                            elif isinstance(constant_value, str):
                                concat_value += constant_value
                            else:
                                concat_value += "TOP"
                        return concat_value
                if i + 1 == len(reverse_chain):
                    break
                # set_trace()
                pre_instr = reverse_chain[i+1]
                if not pre_instr.left_hand_side:
                    # special case: CallInstr with no return value
                    continue
                left_hand = pre_instr.left_hand_side[0]
                if isinstance(left_hand, Register):
                    left_hand_reg_idx = left_hand._idx
                    constant_value = get_concrete_value(current_cfg, block, pc, left_hand_reg_idx)
                    if isinstance(constant_value, Load_Module):
                        callee_name = ".".join(constant_value.module_list)
                        if "format" in callee_name:
                            cmd = get_string_from_format(reverse_record_chains)
                            return cmd
                    elif isinstance(constant_value, str):
                        cmd = constant_value
                        return cmd
        
        return "not found"

    def parse_trigger_definition(self):
        # sources_and_sinks_definition = "/home/iot_2204/lua_analysis/Luabyte_Taint/vulnerability_definitions/test.pyt"
        # sources_and_sinks_definition = "/home/iot_2204/lua_analysis/Luabyte_Taint/vulnerability_definitions/register_action.pyt"
        # sources_and_sinks_definition = "/home/iot_2204/lua_analysis/Luabyte_Taint/vulnerability_definitions/xiaomi.pyt"
        # sources_and_sinks_definition = "/home/iot_2204/lua_analysis/Luabyte_Taint/vulnerability_definitions/register_multi_keyword_without_check.pyt"
        # sources_and_sinks_definition = "./vulnerability_definitions/default.pyt"
        logger.debug("begin to parse configuration of source and sink, file: {}".format(self.sources_and_sinks_definition))
        # print(self.sources_and_sinks_definition)
        self.trigger_definition = parse(self.sources_and_sinks_definition)

    def parse_module(self):
        # TODO: source, bytecode or obfuscated bytecode
        module_name_list = list()
        if os.path.exists(self.search_path):
            if os.path.isfile(self.search_path):
                # this may be a single file in the condition of scan for vulnerability related to command line.
                lua_file_of_cmdline = self.search_path
                file_suffix = lua_file_of_cmdline.split(".")[-1]
                
                if file_suffix == "lua":
                    if is_lua_bytecode(lua_file_of_cmdline):
                        module_name = lua_file_of_cmdline
                        module_name_list.append(module_name)
                    else:
                        # TODO: need to do?
                        # lua source code
                        # compile lua to generate luac
                        pass
                elif file_suffix == "luac":
                    # lua bytecode
                    module_name = lua_file_of_cmdline
                    module_name_list.append(module_name)
            elif os.path.isdir(self.search_path):    
                for root, dirs, files in os.walk(self.search_path):
                    if "gadget_test_chunk" in root:
                        # skip the lua gadget we prepare
                        continue
                    for file in files:
                        file_suffix = file.split(".")[-1]
                        if len(file.split(".")) <= 1:
                            continue
                        abspath_file = os.path.abspath(os.path.join(root, file))

                        # check if the symbol link file exist
                        if os.path.islink(abspath_file) and not os.path.exists(os.path.realpath(abspath_file)):
                            continue
                        if file_suffix == "lua":
                            if is_lua_bytecode(abspath_file):
                                module_name = abspath_file
                                module_name_list.append(module_name)
                            else:
                                # TODO: need to do?
                                # lua source code
                                # compile lua to generate luac
                                pass
                        elif file_suffix == "luac":
                            # lua bytecode
                            module_name = abspath_file
                            module_name_list.append(module_name)
        # set_trace()
        if self.debug:
            self.single_thread_parse_module(module_name_list)
        else:
            self.single_thread_parse_module_with_timeout(module_name_list)
    
    def single_thread_parse_module_with_timeout(self, module_name_list):
        # logger.info(f"parse module:")
        # for i, module_name in enumerate(module_name_list):
        #     logger.info(f"module id: {i}/{len(module_name_list)}, module_name: {module_name}")
        #     with concurrent.futures.ThreadPoolExecutor() as executor:
        #         future = executor.submit(
        #                                 run_with_timeout, 
        #                                 self.thread_target_func_parse_module, 
        #                                 (module_name, )
        #                                 )
        #         try:
        #             future.result()
        #         except Exception as exc:
        #             if module_name in self.modules:
        #                 del self.modules[module_name]
        #             logger.error(f"multi_thread_parse_module error: module_name:{module_name}, error_msg: {exc}")
        #         finally:
        #             executor.shutdown(wait=False)


        logger.info(f"parse module:")
        with concurrent.futures.ThreadPoolExecutor() as executor:
            for i, module_name in enumerate(module_name_list):
                logger.info(f"module id: {i}/{len(module_name_list)}, module_name: {module_name}")
                future = executor.submit(
                                        run_with_timeout, 
                                        self.thread_target_func_parse_module, 
                                        (module_name, ),
                                        timeout = self.timeout
                                        )
                try:
                    future.result()
                except Exception as exc:
                    if module_name in self.modules:
                        del self.modules[module_name]
                    logger.error(f"multi_thread_parse_module error: module_name:{module_name}, error_msg: {exc}")

            

    def thread_target_func_parse_module(self, module_name):
        self.modules[module_name] = lua_module(module_name)
        self.modules[module_name].whole_module = self

    def single_thread_parse_module(self, module_name_list):
        logger.info(f"parse module:")
        for i, module_name in enumerate(module_name_list):
            logger.info(f"module id: {i}/{len(module_name_list)}, module_name: {module_name}")
            self.modules[module_name] = lua_module(module_name)
            self.modules[module_name].whole_module = self

    def generate_callgraph(self):
        logger.info("generate call graph for whole module")
        if not self.debug:
            self.singel_thread_generate_callgraph_with_timeout()
        else:
            for i, module in enumerate(self.modules.values()):
                logger.info(f"module id: {i}/{len(self.modules.values())}, module_name: {module.module_name}")
                module.generate_callgraph(self.callgraph)

    def thread_func_generate_callgraph(self, module):
        module.generate_callgraph(self.callgraph)

    def singel_thread_generate_callgraph_with_timeout(self, timeout=600):
        # for i, module in enumerate(self.modules.values()):
        #     logger.info(f"module id: {i}/{len(self.modules.values())}, module_name: {module.module_name}")
        #     with concurrent.futures.ThreadPoolExecutor() as executor:
        #         future = executor.submit(
        #                                 run_with_timeout, 
        #                                 self.thread_func_generate_callgraph, 
        #                                 (module, )
        #                                 )
                
        #         try:
        #             future.result()
        #         except Exception as exc:
        #             logger.error(f"multi_thread_parse_module error: module_name:{module.module_name}, error_msg: {exc}")
        #         finally:
        #             executor.shutdown(wait=False)

        with concurrent.futures.ThreadPoolExecutor() as executor:
            for i, module in enumerate(self.modules.values()):
                logger.info(f"module id: {i}/{len(self.modules.values())}, module_name: {module.module_name}")
                future = executor.submit(
                                        run_with_timeout, 
                                        self.thread_func_generate_callgraph, 
                                        (module, ),
                                        timeout = self.timeout
                                        )
                
                try:
                    future.result()
                except Exception as exc:
                    logger.error(f"multi_thread_parse_module error: module_name:{module.module_name}, error_msg: {exc}")

    # def identify_CmdlineSource_Sink(self):
    #     logger.info("identify source from command line and sink for whole module")
    #     for module_name, module in self.modules.items():
    #         module.idendify_CmdlineSource_Sink_according_pyt()

    def idendify_source_sink(self):
        logger.info("identify source and sink for whole module")
        # identify source from pattern
        for module_name, module in self.modules.items():
            module.idendify_source_sink_according_pyt()

                
        # set_trace()
        # identify source from source resolve result
        tplink_handler_list_without_check = list()
        file_dir = os.path.dirname(os.path.abspath(__file__))
        tplink_check_file_path = os.path.join(file_dir, "../vulnerability_definitions/tplink_handler_list_without_check")
        with open(tplink_check_file_path) as f:
            tplink_handler_list_without_check = json.load(f)
        for register_name, Source_Identify_list in self.source_identify.items():
            if register_name in ["register_sectype_cb", "register_secname_cb"]:
                continue
            for source_identify in Source_Identify_list:
                param_list = list(source_identify.nested_access["param"].keys())
                for param_idx in param_list:
                    for handler in source_identify.event_handler:
                        if register_name in ["register_keyword_add_data", "register_keyword_set_data", "register_keyword_del_data", "register_keyword_data"] and handler._func_name not in tplink_handler_list_without_check:
                            # skip the handler with check of these four register
                            continue
                        for node in handler.assignment_nodes:
                            if isinstance(node, LuaB_Param_Block):
                                if node._param_idx == param_idx:
                                    # taint the instr
                                    node._param_high_instr.tainted = True
                                    node._param_high_instr.tainted_idx = [0] # represent that only taint the first left hand of high instr of LuaB_Param_Block

                                    # generate the trigger instr
                                    trigger_type = Source_Sink_Type.Source_Param
                                    trigger_word = handler._func_name
                                    logger.debug(f'find source in {handler._func_name}, trigger_word: {trigger_word}, type: {trigger_type}, idx:{param_idx}')
                                    trigger_instance = Source_Param_Trigger(handler, trigger_type, trigger_word,\
                                                                            param_idx, node._param_high_instr, node)
                                    self.source.append(trigger_instance)
                    
        # set_trace()
        # identify sink of lua table in c
        lua_table_info_list = list()
        lua_table_config = os.path.join(self.output_dir, "lua_table/lua_table")
        if os.path.exists(lua_table_config):
            with open(lua_table_config, 'r') as f:
                lua_table = json.load(f)
                exclude_lua_table = ["nixio.so"]
                for lib_name, table_info_list in lua_table.items():
                    if lib_name in exclude_lua_table:
                        continue
                    for table_info in table_info_list:
                        func_name = table_info["name"]
                        lua_table_info_list.append((lib_name, func_name))
        if lua_table_info_list:
            for module_name, module in self.modules.items():
                module.identify_lua_table_func_sink(lua_table_info_list)
        # set_trace()
        # TODO: this phase, determine the sink from lua_table of libc
        logger.info(f"identify source_num: {len(self.source)} sink_num: {len(self.sink)}")
        
        # record all the source in the file
        # set_trace()
        result_path = os.path.join(self.output_dir, "source_identify")
        if not os.path.exists(result_path):
            os.makedirs(result_path)
        source_to_file = list()
        for source in self.source:
            if isinstance(source, Source_Param_Trigger):
                source_instance = {
                    "module_name": source.cfg.lua_module.module_name,
                    "func_name": source.cfg._func_name,
                    "type": source.type.name,
                    "trigger_word": source.trigger_word,
                    "param_idx": source.param_idx
                }
                source_to_file.append(source_instance)
            elif isinstance(source, Source_Ret_Trigger):
                source_instance = {
                    "module_name": source.cfg.lua_module.module_name,
                    "func_name": source.cfg._func_name,
                    "type": source.type.name,
                    "trigger_word": source.trigger_word,
                    "addr": source.addr
                }
                source_to_file.append(source_instance)
        # set_trace()
        with open(os.path.join(result_path, "source"),'w') as f:
            json.dump(source_to_file, f, indent=4)

        # record all the sink in the file
        # set_trace()
        result_path = os.path.join(self.output_dir, "sink_identify")
        if not os.path.exists(result_path):
            os.makedirs(result_path)
        sink_to_file = list()
        for sink in self.sink:
            if isinstance(sink, Sink_Trigger):
                sink_instance = {
                    "module_name": sink.cfg.lua_module.module_name,
                    "func_name": sink.cfg._func_name,
                    "type": sink.type.name,
                    "trigger_word": sink.trigger_word,
                    "param_idx": sink.param_idx,
                    "addr": sink.addr
                }
                sink_to_file.append(sink_instance)
            elif isinstance(sink, Sink_Trigger_Lua_Table_Func):
                sink_instance = {
                    "module_name": sink.cfg.lua_module.module_name,
                    "func_name": sink.cfg._func_name,
                    "type": sink.type.name,
                    "trigger_word": sink.trigger_word,
                    "param_idx": sink.param_idx,
                    "addr": sink.addr
                }
                sink_to_file.append(sink_instance)
        # set_trace()
        with open(os.path.join(result_path, "sink"),'w') as f:
            json.dump(sink_to_file, f, indent=4)


        # generate high level source and sink
        logger.info("generate high level source and sink")
        for source in self.source:
            cfg_of_source = source.cfg
            if cfg_of_source not in self.high_level_source:
                self.high_level_source[cfg_of_source] = list()
                self.high_level_source[cfg_of_source].append(source)
            else:
                self.high_level_source[cfg_of_source].append(source)
        for sink in self.sink:
            cfg_of_sink = sink.cfg
            # if cfg_of_sink._func_name == "startPortScan":
            #     set_trace()
            if cfg_of_sink not in self.high_level_sink:
                self.high_level_sink[cfg_of_sink] = list()
                self.high_level_sink[cfg_of_sink].append(sink)
            else:
                self.high_level_sink[cfg_of_sink].append(sink)
        logger.info(f"CFG num containing source: {len(self.high_level_source.keys())}, CFG num constaining sink: {len(self.high_level_sink.keys())}")
        
    def get_edge_SourceToSink(self):
        logger.debug("find path in call graph from source to sink")
        reverse_cg = self.callgraph.graph.reverse()
        # set_trace()
        for cfg_of_source, source_trigger_list in self.high_level_source.items():
            if cfg_of_source not in self.callgraph.nodes:
                # sometimes, if the func do not have any caller and callee, the func will not exist in the callgraph
                # but this func can be also have the source and sink
                # e.g. tplink sdwan.lua: sdwan_add_entry_async
                if cfg_of_source in self.high_level_sink:
                    # add the path
                    # source and sink are in the same cfg
                    self.cg_search_result[(cfg_of_source, cfg_of_source)] = [[cfg_of_source]]
                continue
            for cfg_of_sink, sink_trigger_list in self.high_level_sink.items():
                if cfg_of_sink not in self.callgraph.nodes:
                    continue

                # if cfg_of_sink._func_name == "wol_wake" and cfg_of_source._func_name == "wol_wake":
                #     set_trace()

                # sink number is little than source number
                # reverse search, sink -> source
                reverse_paths = list(networkx.all_simple_paths(reverse_cg, source=cfg_of_sink, target=cfg_of_source, cutoff=7))
                if not reverse_paths:
                    # there is no path from source to sink
                    continue
                # source -> sink
                search_paths = [path[::-1] for path in reverse_paths]
                self.cg_search_result[(cfg_of_source, cfg_of_sink)] = search_paths
        logger.info(f"there are {len(self.cg_search_result.keys())} possible path from source cfg to sink cfg")
        # logger.debug("get the source->to->sink path")
        # total_debug_messsage = ""
        # for (source, sink), path_list in self.cg_search_result.items():
        #     log_message = "\n"
        #     module_name_source = source.lua_module.module_name
        #     func_name_source = source._func_name
        #     log_message += f"Source: module:{module_name_source:<40}, func:{func_name_source} \n"
        #     # set_trace()
        #     for i, source_trigger in enumerate(self.high_level_source[source]):
        #         log_message += f"SourceTrigger_{i}:{source_trigger}"
        #     module_name_sink = sink.lua_module.module_name
        #     func_name_sink = sink._func_name
        #     log_message += f"\nSink:   module:{module_name_sink:<40}, func:{func_name_sink} \n"
        #     for i, sink_trigger in enumerate(self.high_level_sink[sink]):
        #         log_message += f"SourceTrigger_{i}:{sink_trigger}"
        #     for i, path in enumerate(path_list):
        #         log_message += f"Middle path_{i}: "
        #         for cfg in path:
        #             log_message += " -> "
        #             log_message += f"module:{cfg.lua_module.module_name:<40}, func:{cfg._func_name:<20}"
        #         log_message += "\n\n"
        #     total_debug_messsage += log_message

        # logger.debug(total_debug_messsage)
        # set_trace()

    def vulnerability_discovery(self):
        if self.debug:
            self.vulnerability_discovery_single_thread()
        else:
            self.vulnerability_discovery_single_thread_with_timeout()

    def vulnerability_discovery_single_thread_with_timeout(self):
        logger.debug("begin vulnerability detecting")
        # parse path one by one
        source_to_sink_record = list()
        for (source_of_cfg, sink_of_cfg), path_list in self.cg_search_result.items():
            # get one path
            for link_path in path_list:
                # get source trigger
                for source_trigger in self.high_level_source[source_of_cfg]:
                    #get sink trigger
                    for sink_trigger in self.high_level_sink[sink_of_cfg]:
                        # if source_trigger.cfg._func_name == "set_extendwifi_connect":
                        #     set_trace()
                        # else:
                        #     continue
                        source_to_sink_record.append((source_trigger, sink_trigger, link_path))
                        
        # record_ready, begin to analyze
        single_thread_source_to_sink_analysis_with_timeout(source_to_sink_record, self.vulnerability, timeout=self.timeout)


    def vulnerability_discovery_single_thread(self):
        # set_trace()
        logger.info("begin vulnerability detecting")
        id = 0
        # parse path one by one
        for (source_of_cfg, sink_of_cfg), path_list in self.cg_search_result.items():
            logger.info(f"cfg_source_to_sink id: {id}/{len(self.cg_search_result.keys())}")
            id = id + 1
            # if source_of_cfg._func_name != "startPortScan":
            #     continue
            # set_trace()
            # get one path
            for link_path in path_list:
                # get source trigger
                for source_trigger in self.high_level_source[source_of_cfg]:
                    #get sink trigger
                    for sink_trigger in self.high_level_sink[sink_of_cfg]:
                        # if source_trigger.cfg._func_name == "doSwitchApi":
                        #     # pass 
                        #     set_trace()
                        # else:
                        #     print(source_trigger.cfg._func_name)
                        #     continue
                        start_time = datetime.now()
                        taint_propagation_source_to_sink(source_trigger, sink_trigger, link_path, self.vulnerability)
                        end_time = datetime.now()
                        used_time = (end_time-start_time).total_seconds()
                        global time_of_taint_propagation
                        if used_time > time_of_taint_propagation:
                            time_of_taint_propagation = used_time
                        logger.debug(f"----------------taint propagation time: {time_of_taint_propagation}. {source_trigger.cfg._func_name}, {sink_trigger.cfg._func_name}")


def single_thread_source_to_sink_analysis_with_timeout(source_to_sink_record, vulnerability_list, timeout):
    max_use_time = 0
    id = 0
    # for source_trigger, sink_trigger, link_path in source_to_sink_record:
    #     logger.info(f"vul_path id: {id}/{len(source_to_sink_record)}")
    #     id = id + 1
    #     with concurrent.futures.ThreadPoolExecutor() as executor:
    #         future = executor.submit(
    #                                 run_with_timeout,
    #                                 taint_propagation_source_to_sink,
    #                                 (source_trigger, sink_trigger, link_path, vulnerability_list, ),
    #                                 )
            
            
    #         try:
    #             used_time = future.result()
    #             if used_time > max_use_time:
    #                 max_use_time = used_time
    #         except Exception as exc:
    #             logger.error(f"source_to_sink_analysis error: source:{source_trigger}, sink:{sink_trigger}, error_msg: {exc}")
    #         finally:
    #             executor.shutdown(wait=False)


    with concurrent.futures.ThreadPoolExecutor() as executor:
        for source_trigger, sink_trigger, link_path in source_to_sink_record:
            logger.info(f"vul_path id: {id}/{len(source_to_sink_record)}")
            id = id + 1
            future = executor.submit(
                                    run_with_timeout,
                                    taint_propagation_source_to_sink,
                                    (source_trigger, sink_trigger, link_path, vulnerability_list, ),
                                    timeout = timeout
                                    )
            
            try:
                used_time = future.result()
                if used_time > max_use_time:
                    max_use_time = used_time
            except Exception as exc:
                logger.error(f"source_to_sink_analysis error: source:{source_trigger}, sink:{sink_trigger}, error_msg: {exc}")
   
    return max_use_time

class lua_module:
    def __init__(self, module_name):
        self.module_name = module_name
        self.root_cfg = None
        self.global_var = dict()
        self.generate_cfg()
        self.constant_propagation(self.root_cfg)
        self.whole_module = None # point to the whole module
        logger.debug(f"global_var info: {self.global_var}")
        # reaching definition
        self.reaching_definition_analysis()
        

    def generate_cfg(self):
        # set_trace()
        logger.debug(f"load luac bytecode of {self.module_name}")
        lc = LuaUndump()
        root_chunk = lc.loadFile(self.module_name)
        self.root_cfg = generate_cfg_recursive("0", root_chunk, "root_func", self)
    
    def constant_propagation(self, cfg:CFG):
        """
            do constant propagation for cfg and their sub proto cfg
            two phase:
                calculate the constant in cfg
                propagation upvalue to sub cfg
        """
        logger.debug(f"do constant propagation analysis for func {cfg._func_name}")
        # set_trace()
        # cfg.draw_cfg()
        cfg.constant_propagation = ConstantPropagation(cfg)
        for index, sub_cfg in cfg.proto_func.items():
            self.constant_propagation(sub_cfg)
    
    def generate_callgraph(self, fw_call_graph):
        """
            generate call graph for all firmware lua func
        """
        # point to the fw_call_graph
        logger.debug(f"generate call graph for module: {self.module_name}")
        self.callgraph = fw_call_graph
        CallGraphGeneration(self.callgraph, self.root_cfg)

    def reaching_definition_analysis(self):
        do_RDA_analysis_recursively(self.root_cfg)

    # def idendify_CmdlineSource_Sink_according_pyt(self):
    #     logger.debug("identify CmdlineSource for module: {}".format(self.module_name))
    #     do_CmdlineSource_identify(self.root_cfg, self.whole_module.source)
    #     logger.debug("identify source sink module: {}".format(self.module_name))
    #     do_sink_identify(self.root_cfg, self.whole_module.trigger_definition.sinks, self.whole_module.sink)

    def idendify_source_sink_according_pyt(self):
        logger.debug("identify source for module: {}".format(self.module_name))
        do_source_identify_according_to_pyt(self.root_cfg, self.whole_module.trigger_definition.sources, self.whole_module.source)
        logger.debug("identify source sink module: {}".format(self.module_name))
        do_sink_identify(self.root_cfg, self.whole_module.trigger_definition.sinks, self.whole_module.sink)


    def filter_out_event_register(self, candidate_register:Dict, whole_module):
        logger.debug(f"filter out event register for module: {self.module_name}")
        FilterHandler(candidate_register, self.root_cfg, whole_module)

    def identify_lua_table_func_sink(self, lua_table_info_list):
        do_lua_table_sink_identify(self.root_cfg, lua_table_info_list, self.whole_module.sink)
