import sys
sys.path.append("..")
from .cfg_base import CFGBase
from .lundump import Chunk
from .high_instruction import get_high_level_instruction, create_reg, AssignmentInstr, CallInstr
from typing import List, Dict, Tuple, Optional
from ipdb import set_trace
import matplotlib.pyplot as plt
from networkx.drawing.nx_pydot import graphviz_layout
from analysis.analysis import check_data_depend_instrs
import networkx as nx
from analysis.definition_chains import build_def_use_chain
from utils.logger import setup_logger
from collections import defaultdict
logger = setup_logger(__name__)
debug = True

class LuaB_Block():
    def __init__(self, start, end, cfg=None):
        self._start = start
        self._end = end
        self.cfg = cfg
        self._high_instru = dict() #pc:high level instruction
    
    def print(self):
        print(f"Block: start{self._start}, end{self._end}")
    
    def printInstr(self):
        for pc, high_instr in self._high_instru.items():
            if isinstance(high_instr, AssignmentInstr):
                print(f"pc: {pc}")
                print(high_instr.toString())
            

class LuaB_Entry_Block(LuaB_Block):
    def __init__(self):
        super().__init__(-1, -1) # -1 represent the entry

class LuaB_Exit_Block(LuaB_Block):
    def __init__(self):
        super().__init__(-2, -2) # -2 represent the exit

class LuaB_Param_Block(LuaB_Block):
    def __init__(self, pc, cfg, param_idx, high_instr):
        super().__init__(pc, pc, cfg) # -3 represent the first param, -4 represent the second param, ...
        self._param_idx = param_idx
        self._param_high_instr = high_instr
        

branch_op_call = ["CALL", "TAILCALL"]
branch_op_step_one = ["EQ", "LT", "LE", "TEST", "TESTSET", "TFORLOOP"]
branch_op_step_sBX = ["FORLOOP"]
branch_op_step_sBX_uncondition = ["JMP", "FORPREP"]
branch_op = []
branch_op.extend(branch_op_call)
branch_op.extend(branch_op_step_one)
branch_op.extend(branch_op_step_sBX)
branch_op.extend(branch_op_step_sBX_uncondition)
potential_branch_op = ["LOADBOOL"]


class CFG(CFGBase):
    """
    Generate a complete control flow graph (CFG) for the analyzed lua bytecode chunk.
    """
    def __init__(self, chunk, func_name, lua_module, location_id):
        super(CFG, self).__init__()
        self._block = {}
        self._edge = []
        self._initialize_graph()
        self._chunk = chunk
        self._func_name = func_name # the func name of this cfg
        self._proto_name = dict() # the sub proto name dict
        self.proto_func = dict() # save the child proto
        self._high_instrs = list() # used in reaching definition
        self.lua_module = lua_module # point to the lua module of this cfg
        self.location_id = location_id # the function level and index, root chunk -> "0" first sub func of root chunk -> "0_0"
        self.upvalue = dict() # used for constant analysis
        self.parent_cfg = None
        self.constant_propagation = None
        self.RDA_analysis = None
        self.secondary_nodes = dict() # used for vulnerability analysis
        self.generate_cfg()
        self.assignment_nodes = list()
        self.def_use = defaultdict(list)   
        self.filter_assignment_cfg_nodes()     
        self.collect_high_instr()
        self.generate_subproto_cfg()

    def get_use(self, high_instr, left_hand_reg_idx=None):
        """
            get all the usage of high_instr
            
            left_hand_idx:
                represent the left hand that we only consider
                default: None, represent all left hand 
        """
        if isinstance(high_instr, AssignmentInstr) and high_instr.in_closure == True:
            # the assignment instr may be in the middle instr
            # in this situaton, return empty list because the instr in closure will not save value in the left hand
            empty_list = list()
            return empty_list
        if high_instr in self.def_use:
            return self.def_use[high_instr]
        # set_trace()
        reachable_instr_list = self.RDA_analysis.get_reached_instr(high_instr)
        for reachable_instr in reachable_instr_list:
            # in this situation, we need not to exclude the assignment instr in the closure
            # because it can may use the high instr, and pass it to the next cfg
            if isinstance(reachable_instr, (AssignmentInstr, CallInstr)):
                if check_data_depend_instrs(reachable_instr, high_instr, left_hand_reg_idx): 
                    self.def_use[high_instr].append(reachable_instr)
        return self.def_use[high_instr]

    def get_def_use_bak(self):
        if not self.def_use:
            self.def_use = build_def_use_chain(self)
        return self.def_use

    def get_secondary_nodes(self, high_instr, left_hand_reg_idx=None):
        """
            get the assignment relationship from source to secondary assign node.

            left_hand_idx:
                represent the left hand that we only consider
                default: None, represent all left hand 
        """
        if high_instr in self.secondary_nodes:
            # already resolve
            return self.secondary_nodes[high_instr]
        # set_trace()
        if isinstance(high_instr, AssignmentInstr) and high_instr.in_closure == True:
            # sometimes, the source trigger just in the CLOSRE, such as GETUPVAL
            empty_secondary_instr_list = list()
            self.secondary_nodes[high_instr] = empty_secondary_instr_list

        # if self._func_name == "wol_wake":
        #     set_trace()

        # propagate reassignments of the source high_instr
        secondary_instr_list = list()
        leave_to_analyze_instr = [high_instr]
        while leave_to_analyze_instr:
            middle_instr = leave_to_analyze_instr.pop(0)
            for use_instr in self.get_use(middle_instr, left_hand_reg_idx) if middle_instr == high_instr else self.get_use(middle_instr):
                if use_instr not in secondary_instr_list:
                    if use_instr not in leave_to_analyze_instr:
                        leave_to_analyze_instr.append(use_instr)
            secondary_instr_list.append(middle_instr)

        # remove source high_instr from result
        del secondary_instr_list[0]

        self.secondary_nodes[high_instr] = secondary_instr_list
        # if self._func_name == "set_stat_params_config":
        #     set_trace()
        return self.secondary_nodes[high_instr]

    def get_secondary_nodes_bak(self, high_instr, left_hand_reg_idx=None):
        """
            get the assignment relationship from source to secondary assign node.

            left_hand_idx:
                represent the left hand that we only consider
                default: None, represent all left hand 
        """
        if high_instr in self.secondary_nodes:
            # already resolve
            return self.secondary_nodes[high_instr]
        # propagate reassignments of the source high_instr
        secondary_instr_list = [high_instr]
        completed_instr = []
        i = 0
        while True:
            # Retrieves each instru in secondary_instr_list in order
            self.update_assignments(secondary_instr_list, secondary_instr_list[i], left_hand_reg_idx if secondary_instr_list[i] == high_instr else None)
            # add the instru to completed_instr
            completed_instr.append(secondary_instr_list[i])
            if len(completed_instr) == len(secondary_instr_list):
                # secondary instr query finish
                break
            i = i + 1

        # remove source high_instr from result
        del secondary_instr_list[0]

        self.secondary_nodes[high_instr] = secondary_instr_list
        # if self._func_name == "set_stat_params_config":
        #     set_trace()
        return self.secondary_nodes[high_instr]

    def update_assignments(self, secondary_instr_list, target_instr, left_hand_reg_idx):
        for node in self.assignment_nodes:
            for _, high_instr in node._high_instru.items():
                # if self._func_name == "set_stat_params_config" and high_instr.pc == 57:
                #     set_trace()
                # compare every assignment high_instr of every assign node with target high instr
                if isinstance(high_instr, (AssignmentInstr, CallInstr)):
                    # TODO: fined grained judgement
                    if high_instr not in secondary_instr_list and \
                        self.RDA_analysis.check_reaching_definition(target_instr, high_instr, node):
                        # if target_instr can reach high_instr
                        self.append_instr_if_reassigned(secondary_instr_list, target_instr, left_hand_reg_idx, high_instr)

    def append_instr_if_reassigned(self, secondary_instr_list, target_instr, left_hand_reg_idx, assign_high_instr):
        """
            if left hand of target_instr is used as right hand of assign_high_instr, 
            then we think that assign_high_instr is a secondary instr of target_instr

            assign_high_instr: AssignmentInstr or CallInstr
        """
        if check_data_depend_instrs(assign_high_instr, target_instr, left_hand_reg_idx):
            secondary_instr_list.append(assign_high_instr)

    def filter_assignment_cfg_nodes(self):
        """
            get the cfg node that contains the 'high_level_instr_type' type instructions

            two type:
            1. AssignmentTnstr
            2. CALL OP, becase the return value of call can be tainted by parameter
        """
        for node in self.graph.nodes():
            for pc, high_instr in node._high_instru.items():
                if isinstance(high_instr, (AssignmentInstr, CallInstr)):
                    self.assignment_nodes.append(node)
                    break

    def generate_subproto_cfg(self):
        for index, sub_chunk in enumerate(self._chunk.protos):
            proto_name = self._proto_name[index] if index in self._proto_name else f"func_unknow_{self.location_id}_{index}"
            logger.debug(f"generate cfg,  location_id: {self.location_id}_{index}, func_name: {proto_name}")
            sub_proto_cfg = CFG(sub_chunk, proto_name, self.lua_module, f"{self.location_id}_{index}")
            self.proto_func[index] = sub_proto_cfg
            sub_proto_cfg.parent_cfg = self

    def generate_cfg(self):
        self.parse_bacic_block()
        self.add_node_to_graph()
        self.add_entry_exit_param_node()
    
    def parse_bacic_block(self):
        '''
        travel the inst, get the info of basic block and edges for building CFG
        '''
        def add_jump_target(jump_target, edges):
            for edge in edges:
                target_pc = edge[1]
                jump_target.append(target_pc)
        block_start = 0
        block_end = 0
        last_pc = len(self._chunk.instructions)
        CLOSURE_op = (-1, -1) # used to get sub proto name
        jump_target = [] # record the branch target pc 
        for pc, inst in enumerate(self._chunk.instructions):
            if inst.name in branch_op:
                # add new BB
                if inst.name != "FORLOOP":
                    block_end = pc
                    block = LuaB_Block(block_start, block_end, self)
                    self._block[block_start] = block
                else:
                    # treat the singe FORLOOP op as a BB
                    pre_BB = LuaB_Block(block_start, pc-1, self)
                    self._block[block_start] = pre_BB
                    FORLOOP_BB = LuaB_Block(pc, pc, self)
                    self._block[pc] = FORLOOP_BB
                
                edges = []

                # get the edge info
                if inst.name in branch_op_call:
                    # treat the call op as a branch op
                    edges = [(block_start, pc+1)]
                elif inst.name in branch_op_step_one:
                    # if pc == 20 and self._func_name == "get_df_info":
                    #     set_trace()
                    edges = [(block_start, pc+1), (block_start, pc+2)]
                elif inst.name in branch_op_step_sBX:
                    # for pre_BB
                    edges = [(block_start, pc)]
                    # for FORLOOP_BB
                    edges.extend([(pc, pc+1), (pc, pc+1+inst.B)])
                elif inst.name in branch_op_step_sBX_uncondition:
                    # if pc == 17:
                    #     set_trace()
                    edges = [(block_start, pc+1+inst.B)]
                
                self._edge.extend(edges)
                add_jump_target(jump_target, edges)

                # if self._func_name == "_modify_ipsec_conns_for_l2tp":  
                #     for p, s in edges:
                #         if 129 == s or 130 == s:
                #             print(pc, s)
                #             set_trace()
                #             print(123)

                block_start = pc + 1
            
            # potential_branch_op
            if inst.name in potential_branch_op:
                if inst.name != "LOADBOOL":
                    if inst.name == "LOADBOOL":
                        # LOADBOOL A B C R(A) := (Bool)B; if (C) PC++
                        if inst.C:
                            edges = [(block_start, pc+2)]
                            self._edge.extend(edges)
                            add_jump_target(jump_target, edges)
                            block_start = pc + 1


            if pc == last_pc - 1:
                block_end = pc
                block = LuaB_Block(block_start, block_end, self)
                self._block[block_start] = block

            # get the sub func name according to the relationship of CLOSURE and SETGLOBAL OP.
            # CLOSURE A Bx R(A) := closure(KPROTO[Bx], R(A), ... ,R(A+n))
            # SETGLOBAL A Bx Gbl[Kst(Bx)] := R(A)
            if inst.name == "CLOSURE":
                CLOSURE_op = (inst.A, inst.B)
            if inst.name == "SETGLOBAL":
                if inst.A == CLOSURE_op[0]:
                    proto_index = CLOSURE_op[1]
                    constant = self._chunk.constants[inst.B]
                    if constant.type == 4: #string type
                        # set_trace()
                        proto_name = constant.data
                        self._proto_name[proto_index] = proto_name
                        CLOSURE_op = (-1, -1)

        # if self._func_name == "_modify_ipsec_conns_for_l2tp":
            
        #     for precessor_pc, successor_pc in self._edge:
        #         if precessor_pc == 128:
        #             print(precessor_pc, successor_pc)
        #     set_trace()
        #     print(123)

        # sometimes, the branch target pc is not the beginning of a BB.
        # we need to construct new BB for branch target pc.
        def get_closest_key(dictionary, target):
            smaller_keys = [key for key in dictionary.keys() if key < target]
            if not smaller_keys:
                return None
            closest_key = min(smaller_keys, key=lambda x: target - x)
            return closest_key
        def correct_edge(self, pc_pre, pc_now):
            for i in range(len(self._edge)):
                if self._edge[i][0] == pc_pre:  
                    self._edge[i] = (pc_now, self._edge[i][1])  
        # set_trace()
        jump_target = list(set(jump_target))
        for target_pc in jump_target:
            if target_pc not in self._block:
                # if target_pc == 2 and self._func_name == "func_unknow_0_2":
                #     set_trace()
                closest_pc = get_closest_key(self._block, target_pc)
                if closest_pc != None:
                    closest_BB = self._block[closest_pc]
                    if target_pc <= closest_BB._end:
                        # sperate the original BB into two BB
                        secondBB_end = closest_BB._end
                        del self._block[closest_pc]
                        firstBB = LuaB_Block(closest_pc, target_pc-1, self)
                        secondBB = LuaB_Block(target_pc, secondBB_end, self)
                        self._block[closest_pc] = firstBB
                        self._block[target_pc] = secondBB

                        # correct the edge info due to the BB build
                        # first modify the original edge to new BB
                        correct_edge(self, closest_pc, target_pc)
                        # second, add edge between firstBB and secondBB
                        self._edge.append((closest_pc, target_pc))
        
        # search the RETURN OP, and remove the successor edges if exist.
        for precessor_pc, successor_pc in self._edge:
            precessor_last_pc = self._block[precessor_pc]._end
            if self._chunk.instructions[precessor_last_pc].name == "RETURN":
                self._edge.remove((precessor_pc, successor_pc))

        # if self._func_name == "_modify_ipsec_conns_for_l2tp":
            
        #     for precessor_pc, successor_pc in self._edge:
        #         if precessor_pc == 128:
        #             print(precessor_pc, successor_pc)
        #     set_trace()
        #     print(123)



    def add_node_to_graph(self):
        #print("get the block info")
        in_colsure = False
        for _, block in self._block.items():
            for pc in range(block._start, block._end+1):
                block._high_instru[pc], in_closure_return = get_high_level_instruction(pc, self._chunk.instructions[pc], self._chunk, in_colsure)
                in_colsure = in_closure_return
            self.graph.add_node(block)
            #block.print()
        # print("get the edge info")
        # print(self._edge)
        # set_trace()
        for edge in self._edge:
            src, dst = edge[0], edge[1]
            try:
                src_node = self._block[src]
                dst_node = self._block[dst]
                self.graph.add_edge(src_node, dst_node)
            except:
                # set_trace()
                # print(src, dst)
                raise Exception("add_node_to_graph")

    def add_entry_exit_param_node(self):
        """
            this function is used to add entry, exit and param node to cfg.
        """
        first_node = self._block[0] # first node start is pc 0
        # last nodes may not be only one, we determine them according to the node out degree.
        last_nodes = [node for node, degree in self.graph.out_degree() if degree == 0]

        entry_block = LuaB_Entry_Block()
        exit_block = LuaB_Exit_Block()

        # generate the param block
        param_blocks_dict = {}
        for param_idx in range(self._chunk.numParams):
            param_reg = create_reg(param_idx)
            left_hand = [param_reg]
            right_hand = []
            high_instr = AssignmentInstr(-3-param_idx, left_hand, right_hand, None)
            param_block = LuaB_Param_Block(-3-param_idx, self, param_idx, high_instr)
            param_block._high_instru[-3-param_idx] = high_instr
            param_blocks_dict[param_idx] = param_block
            # add the param block to cfg._block
            self._block[-3-param_idx] = param_block
        
        # if param exist, link: entry block -> first para block, last para block -> pc:0 block
        if self._chunk.numParams:
            self.graph.add_edge(entry_block, param_blocks_dict[0])
            self.graph.add_edge(param_blocks_dict[self._chunk.numParams-1], first_node)
            # link the param block to each other
            for idx in range(0, self._chunk.numParams-1):
                self.graph.add_edge(param_blocks_dict[idx], param_blocks_dict[idx+1])
        else:
            # link: entry block -> pc:0 block
            self.graph.add_edge(entry_block, first_node)
        
        # link: last node -> exit block
        for last_node in last_nodes:
            self.graph.add_edge(last_node, exit_block)

    def collect_high_instr(self):
        # collect the high instrs
        tmp_high_instr_dict = {}
        for _, block in self._block.items():
            tmp_high_instr_dict.update(block._high_instru)
        self._high_instrs = [instr for pc, instr in sorted(tmp_high_instr_dict.items())]

    def draw_cfg(self):
        pos = graphviz_layout(self.graph, prog="dot")
        
        node_labels = dict()
        for node in self.graph.nodes:
            if isinstance(node, LuaB_Param_Block):
                node_labels[node] = f"Param idx_{node._param_idx}"
            elif isinstance(node, LuaB_Entry_Block):
                node_labels[node] = f"Entry"
            elif isinstance(node, LuaB_Exit_Block):
                node_labels[node] = f"Exit"
            else:
                node_labels[node] = f"Normal start:{node._start} end{node._end}"
        
        # 设置节点和边的属性
        node_size = 3000  # 节点大小
        node_color = 'lightblue'  # 节点颜色
        edge_color = 'gray'  # 边颜色
        font_size = 12  # 字体大小
        font_weight = 'bold'  # 字体加粗
        arrow_size = 20  # 设置箭头大小

        # 绘制图形
        plt.figure(figsize=(30*3, 24*3))  # 图的大小
        nx.draw(self.graph, pos, labels=node_labels, with_labels=True, node_size=node_size, node_color=node_color,
                font_size=font_size, font_weight=font_weight, edge_color=edge_color,
                arrows=True, arrowsize=arrow_size, width=2, alpha=0.7)
        # nx.draw(self.graph, pos, with_labels=True, labels=node_labels, node_color='lightblue', node_size=2000, font_size=15, font_weight='bold', arrows=True)
        plt.title(f"Graph : {self._func_name}")
        plt.savefig(f"{self._func_name}.png")  
        plt.close()  
    
    def __deepcopy__(self):
        return self


# analyze the chunk recursively and get the cfg 
def get_cfg_dict(locate:str, chunk:Chunk, func_name:str, file_name) -> Dict[str, CFG]:
    """
    locate: the func location in this luac file.
            e.g. 0 -> root chunk, 0+0 -> first function, 0+1 -> second function, 0+1+0, first function of second function
    """
    cfg_dict = dict()
    cfg_obj = CFG(chunk)
    cfg_obj._func_name = func_name
    cfg_obj._file_name = file_name
    cfg_dict[locate] = cfg_obj
    
    for index, sub_chunk in enumerate(chunk.protos):
        proto_name = cfg_obj._proto_name[index] if index in cfg_obj._proto_name else f"func_unknow_{locate}+{index}"
        sub_cfg_dict = get_cfg_dict(f"{locate}+{index}", sub_chunk, proto_name, file_name)
        cfg_dict.update(sub_cfg_dict)
    return cfg_dict

def generate_cfg_recursive(location_id:str, chunk:Chunk, func_name:str, lua_module):
    """
        generate cfg from root chunk recursively
    """
    
    # if debug == True:
    #     chunk.print()
    # logger.debug("luac decompile info: \n" + chunk.get_decompile())
    logger.debug(f"generate cfg,  location_id: {location_id}, func_name: {func_name}")
    return CFG(chunk, func_name, lua_module, location_id)