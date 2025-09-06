import sys
import re
sys.path.append("..")
import hashlib
from analysis.constant_propagation import get_constant, ConstantType, Load_Module
from enum import Enum
import matplotlib.pyplot as plt
import networkx as nx
from .cfg_base import CFGBase
from .cfg import CFG, LuaB_Param_Block
from ipdb import set_trace
from utils.logger import setup_logger

# logger = setup_logger(__name__, log_to_file=True, log_filename='LuabyteTaint_cg.log')
logger = setup_logger(__name__)

class CallGraph(CFGBase):
    """
    Use for CallGraphGenerate a complete control flow graph (CFG) for the analyzed lua bytecode chunk.
    """
    def __init__(self):
        super(CallGraph, self).__init__()
        self._initialize_graph()
        self.nodes = list()
        self.callsite = dict() # key: (caller, calle), value: (callsite_instr, callsite_addr)

    def draw_graph(self):
        plt.figure(figsize=(24, 18))
        node_labels = dict()
        for cfg in self.graph.nodes:
            if isinstance(cfg, CFG):
                label = ""
                label += f"module: {cfg.lua_module.module_name[-10:]}" + "\n"
                label += f"func:   {cfg._func_name}"
                node_labels[cfg] = label
        
        pos = nx.spring_layout(self.graph, seed=42, k=0.5, iterations=50)
        # 设置节点和边的属性
        node_size = 3000  # 节点大小
        node_color = 'lightblue'  # 节点颜色
        edge_color = 'gray'  # 边颜色
        font_size = 12  # 字体大小
        font_weight = 'bold'  # 字体加粗
        arrow_size = 20  # 设置箭头大小

        # 绘制图形
        plt.figure(figsize=(30, 24))  # 图的大小
        nx.draw(self.graph, pos, labels=node_labels, with_labels=True, node_size=node_size, node_color=node_color,
                font_size=font_size, font_weight=font_weight, edge_color=edge_color,
                arrows=True, arrowsize=arrow_size, width=2, alpha=0.7)
        # nx.draw(self.graph, pos, with_labels=True, labels=node_labels, node_color='lightblue', node_size=2000, font_size=15, font_weight='bold', arrows=True)
        plt.title(f"Call Graph")
        plt.savefig(f"callgraph.png")  
        plt.close()  



class CallProperty(Enum):
    caller = "caller"
    callee = "callee"

class CG_node:
    """
        the node fo Call Graph
    """
    def __init__(self, cfg:CFG, property:str, callsite:int):
        self.cfg = cfg 
        self.property = property # caller/callee
        self.callsite = callsite # instr num in caller

branch_call_op = ["CALL", "TAILCALL"]



def get_combined_hash(value1, value2):
    combined = str(value1) + str(value2)
    return hashlib.md5(combined.encode()).hexdigest()

def record_callgraph(callgraph, caller, callee, callsite_block, callsite_instr, callsite_addr):
    # record callsite
    already_in_callgraph = False
    # hash = get_combined_hash(caller, callee)
    search_key = (caller, callee)
    callsite_info = (callsite_block, callsite_instr, callsite_addr)
    if search_key in callgraph.callsite:
        if callsite_info not in callgraph.callsite[search_key]:
            callgraph.callsite[search_key].append(callsite_info)
        already_in_callgraph = True
    else:
        callgraph.callsite[search_key] = list()
        callgraph.callsite[search_key].append(callsite_info)
    # add node into graph
    if not already_in_callgraph:
        add_edge_to_callgraph(caller, callee, callgraph)

def add_edge_to_callgraph(caller, callee, callgraph:CallGraph):
    if caller not in callgraph.nodes:
        callgraph.nodes.append(caller)
        callgraph.graph.add_node(caller)
    if callee not in callgraph.nodes:
        callgraph.nodes.append(callee)
        callgraph.graph.add_node(callee)
    callgraph.graph.add_edge(caller, callee)

def CallGraphGeneration(callgraph:CallGraph, cfg:CFG):
    """
        recursively generate call graph for cfg
    """
    # do not generate call graph in root func
    if cfg._func_name != "root_func":
        logger.debug(f"generate call graph for func: {cfg._func_name}")
        for block_addr, block in cfg._block.items():
            # when generating cfg, we treat the function call instr () as a branch op 
            # set_trace()
            if isinstance(block, LuaB_Param_Block):
                continue
            last_instr = cfg._chunk.instructions[block._end]
            if last_instr.name in branch_call_op:
                callsite_addr = block._end
                callsite_instr_highlevel = block._high_instru[callsite_addr]
                # print(f"function_name: {cfg._func_name}, OP:{last_instr.name}, callsite:{callsite_addr}")
                
                # the process of CALL and TAILCALL is same
                reg_idx_of_callfunc = last_instr.A
                # if cfg._func_name == "index" and callsite_addr == 79 and cfg.lua_module.module_name == "/home/iot_2204/lua_analysis/Luabyte_Taint/rootfs/tplink_TL_R470GP/luci/controller/admin/l2tp.luac":
                #     set_trace()
                callee = get_callee(cfg, block, callsite_addr, reg_idx_of_callfunc)
                if isinstance(callee, CFG):
                    record_callgraph(callgraph, cfg, callee, block, callsite_instr_highlevel, callsite_addr)
                elif isinstance(callee, Load_Module):
                    # two situation
                    # caller and callee are in the different luac modules
                    # search callee cfg in the whole module
                    
                    if callee.is_module_custom:
                        # situation one:
                        #   caller and callee are in the different luac modules
                        #   search callee cfg in the whole module
                        module_list = callee.module_list
                        whole_module = cfg.lua_module.whole_module
                        module_name = ".".join(module_list[:-1])  # match.group(1)
                        func_name = module_list[-1]
                        callee_cfg = search_cfg_in_whole_module(whole_module, module_name, func_name)
                        if isinstance(callee_cfg, CFG):
                            record_callgraph(callgraph, cfg, callee_cfg, block, callsite_instr_highlevel, callsite_addr)
                        elif isinstance(callee_cfg, str):
                            logger.debug(f"callee is basic lua func:  module:{cfg.lua_module.module_name}, func:{cfg._func_name}, callsite:{callsite_addr} target:{callee_cfg}")
                        else:
                            # TODO: temprately modify for test
                            temprate = False
                            if temprate:
                                logger.error(f"call target resolve: {module_name}.{func_name} search_cfg_in_whole_module error")
                            else:
                                # if "io" in module_name:
                                #     set_trace()
                                logger.error(f"call target resolve: {module_name}.{func_name} search_cfg_in_whole_module error")
                                # set_trace()
                                # raise Exception(f"call target resolve: {module_name}.{func_name} search_cfg_in_whole_module error")

                    else:
                        # situation two:
                        #   basic func call: os.system, print etc 
                        module_list = callee.module_list
                        basic_callee_str = ".".join(module_list)
                        logger.debug(f"callee is basic lua func:  module:{cfg.lua_module.module_name}, func:{cfg._func_name}, callsite:{callsite_addr} target:{basic_callee_str}")
                elif isinstance(callee, str):
                        logger.debug(f"callee is basic lua func:  module:{cfg.lua_module.module_name}, func:{cfg._func_name}, callsite:{callsite_addr} target:{callee}")
    # call graph generation recursively
    for index, sub_cfg in cfg.proto_func.items():
        CallGraphGeneration(callgraph, sub_cfg)

def search_cfg_in_whole_module(whole_module, module_name, func_name):
    """
        search the module in the whole_module, and get the func in the module

        return, CFG, str or None
    """
    # TODO: the bellow need to be solved.
    # if module_name == "luci.fs" and func_name == "unlink":
    #     set_trace()
    
    # TODO: change the module name resolution
    
    # treat the uci module specially 
    if f".uci.cursor" in f"{module_name}.{func_name}" or "uci.cursor" == f"{module_name}.{func_name}":
        return f"{module_name}.{func_name}"
    
    for sub_module_name, module in whole_module.modules.items():
        if module_name.replace(".","/") in sub_module_name:
            # set_trace()
            for func_cfg in module.root_cfg.proto_func.values():
                if func_cfg._func_name == func_name:
                    # TODO: change the proto restore in CFG
                    return func_cfg
            
            # not found a cfg
            # may be a global value that point to a function of another module
            """
                -- call target resolve: luci.fs.unlink search_cfg_in_whole_module error
                local e = require("nixio.fs")
                unlink = e.unlink
            """
            if func_name in module.global_var:
                nested_func = module.global_var[func_name]
                if isinstance(nested_func, CFG):
                    return func_cfg
                elif isinstance(nested_func, Load_Module):

                    if nested_func.is_module_custom:
                        module_list = nested_func.module_list
                        module_name = ".".join(module_list[:-1])  # match.group(1)
                        func_name = module_list[-1]
                        return search_cfg_in_whole_module(whole_module, module_name, func_name)
                    else:
                        module_list = nested_func.module_list
                        return ".".join(module_list)
                elif isinstance(nested_func, str):
                    # global_var["xx"] = os.system
                    return nested_func
    return


def get_callee(cfg:CFG, block, pc, reg_idx):
    """
        get the callee in the block with pc, in the cfg

        return: cfg instance or Load_Module instance
    """
    # func_name:dns_check_domain_conflict|0_4, pc:7, reg_idx:4
    # if cfg._func_name == "func_unknow_0_39" and pc == 23:
    #     set_trace()
    constant_list = cfg.constant_propagation.get_constant_before_pc(block, pc)
    func_constant = get_constant(constant_list, reg_idx)
    if func_constant.type == ConstantType.Constant:
        func_call = func_constant.value
        if isinstance(func_call, CFG):
            return func_call
        elif isinstance(func_call, Load_Module):
            # two situation: 
            #   1. other module func call: require("xxx").xxx
            #   2. basic func call module : io.read().find
            return func_call
        elif isinstance(func_call, str):
            # two situation:
            #   1. require("xxx")
            #   2. os.system()xx
            return func_call
        else:
            # set_trace()
            raise Exception("resolve call target: neither cfg or require")
    else:
        # set_trace()
        module_name = cfg.lua_module.module_name
        func_name = cfg._func_name
        location_id = cfg.location_id
        logger.error(f"resolve call target: not constant, module_name:{module_name}, func_name:{func_name}|{location_id}, pc:{pc}, reg_idx:{reg_idx}")
        # set_trace()
        # raise Exception("resolve call target: not constant")
        """
            -- lua/ssl.lua 
            local unpack = table.unpack or unpack  -----is not constant

            -- We must prevent the contexts to be collected before the connections,
            -- otherwise the C registry will be cleared.
            local registry = setmetatable({}, { __mode = "k" })

            --
            --
            --
            local function optexec(func, param, ctx)
                if param then
                    if type(param) == "table" then
                        return func(ctx, unpack(param))
                    else
                        return func(ctx, param)
                    end
                end
                return true
            end
        """
    
    return None



