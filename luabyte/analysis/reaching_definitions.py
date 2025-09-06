import sys
sys.path.append("..")
from cfg.high_instruction import AssignmentInstr, CallInstr, Compare_instance, Depend_instance
from .lattice import Lattice
from .analysis import check_definition_need_killed, check_lefthand_need_killed
from utils.logger import setup_logger
from ipdb import set_trace
import networkx as nx

logger = setup_logger(__name__)

class RDA_Analysis:
    """Run the RDA analysis."""
    def __init__(self, cfg):
        self.cfg = cfg
        self.constraint_table = dict()
        self.initialize_constraint_table()
        self.lattice = Lattice(self, cfg._high_instrs)
        self.fixpoint_runner()

    def initialize_constraint_table(self):
        """Collects all given cfg nodes and initializes the table with value 0."""
        self.constraint_table.update(dict.fromkeys(self.cfg.graph.nodes(), 0))
        
    def constraint_join(self, cfg_nodes):
        """Looks up all cfg_nodes and joins the bitvectors by using logical or."""
        r = 0
        for e in cfg_nodes:
            r = r | self.constraint_table[e]
        return r

    def join(self, cfg_node_list):
        """Joins all constraints of nodes and returns them.
        This represents the JOIN auxiliary definition from Schwartzbach."""
        return self.constraint_join(cfg_node_list)

    def arrow(self, JOIN, checked_left_hand):
        """Removes all previous assignments from JOIN that have the same left hand side.
        This represents the arrow id definition from Schwartzbach."""
        # TODO: 可达分析时：精确化的可达分析，比如如果instr有多个left hand, 那么kill的时候，不能因为只有一个left hand匹配，就把所有的都kill掉
        r = JOIN
        for instr in self.lattice.get_elements(JOIN):
            for search_left_hand in instr.left_hand_side:
                if Compare_instance(search_left_hand, checked_left_hand) or Depend_instance(checked_left_hand, search_left_hand):
                    r = r ^ self.lattice.el2bv[instr] # # can only set xor once : 1 ^ 1 = 1, True ; 1 ^ 0 = 1, Wrong
                    break  # jmp out 'search_left_hand' loop 
        return r


    def fixpointmethod(self, cfg_node):
        """The most important part of PyT, where we perform
        the variant of reaching definitions to find where sources reach.
        """
        arrow_result = self.join(self.cfg.graph.predecessors(cfg_node)) 
        for pc, high_instr in cfg_node._high_instru.items():
            # if isinstance(high_instr, (AssignmentInstr,CallInstr)): 
            if isinstance(high_instr, CallInstr) or \
                (isinstance(high_instr, AssignmentInstr) and high_instr.in_closure == False): 
                # kill
                for i in range(len(high_instr.left_hand_side)):
                    left_hand_variable = high_instr.left_hand_side[i]
                    if check_lefthand_need_killed(high_instr, i):
                    # if check_definition_need_killed(high_instr):
                        arrow_result = self.arrow(arrow_result, left_hand_variable)
                # generation:
                arrow_result = arrow_result | self.lattice.el2bv[high_instr]
        
        self.constraint_table[cfg_node] = arrow_result

    def fixpoint_runner(self):
        """Work list algorithm that runs the fixpoint algorithm."""
        q = list(self.cfg.graph.nodes())

        while q != []:
            x_i = self.constraint_table[q[0]]  # x_i = q[0].old_constraint
            self.fixpointmethod(q[0])  # y = F_i(x_1, ..., x_n);
            y = self.constraint_table[q[0]]  # y = q[0].new_constraint

            if y != x_i:
                for node in self.cfg.graph.successors(q[0]):  # for (v in dep(v_i))
                    if node not in q:
                        q.append(node)  # q.append(v):
                self.constraint_table[q[0]] = y  # q[0].old_constraint = q[0].new_constraint # x_i = y
            q = q[1:]  # q = q.tail()  # The list minus the head
    
    def check_reaching_definition(self, instr1, instr2, instr2_block):
        """
            check whether the definition of instr1 can reach the instr2 in cfg.
        """
        if isinstance(instr1, AssignmentInstr) and instr1.in_closure == True:
            # the assignment instr in closure has not create in lattice
            return False
        definition_before_instr2 = self.get_constraint_before_instr(instr2, instr2_block)
        definition_map_instr1 = self.lattice.el2bv[instr1]
        

        # check instr1 definition reach after instr2 
        if definition_before_instr2 & definition_map_instr1 != 0:
            return True
        else:
            return False

    def get_reachable_instr_in_block(self, assignment_instr, block, instr_in_the_block = False):
        """
            find all the assignment instr in the block that assignment_instr can reach
            Thir param block is all successors of the block that contains assignment_instr
        """
        reachable_instr = list()
        if isinstance(assignment_instr, AssignmentInstr) and assignment_instr.in_closure == True:
            # instr in cloure can not reach any instr in the current cfg
            return reachable_instr

        definition_map_assignment_instr = self.lattice.el2bv[assignment_instr]
        definition_before_block = self.constraint_join(self.cfg.graph.predecessors(block))
        definition_before_instr = definition_before_block
        for pc, high_instr in block._high_instru.items():
            # check if assignment_instr can reach high_instr
            if not instr_in_the_block:
                if definition_before_instr & definition_map_assignment_instr != 0:
                    reachable_instr.append(high_instr)
            else:
                if pc > assignment_instr.pc:
                    if definition_before_instr & definition_map_assignment_instr != 0:
                        reachable_instr.append(high_instr)

            # TODO: CallInstr need consider?
            # if isinstance(high_instr, (AssignmentInstr,CallInstr)): 
            if (isinstance(high_instr, AssignmentInstr) and high_instr.in_closure == False) or \
                isinstance(high_instr, CallInstr): 
                # kill
                for i in range(len(high_instr.left_hand_side)):
                    left_hand_variable = high_instr.left_hand_side[i]
                    if check_lefthand_need_killed(high_instr, i):
                    # if check_definition_need_killed(high_instr):
                        definition_before_instr = self.arrow(definition_before_instr, left_hand_variable)
                
                # generation:
                definition_before_instr = definition_before_instr | self.lattice.el2bv[high_instr]
        
        return reachable_instr
    
    def get_reached_instr(self, instr):
        """
            get all the assignment instructions that instr can reach
        """
        reached_instr = list()

        # first, get corresponding block of instr
        block_instr = None
        for _, block in self.cfg._block.items():
            if block._start <= instr.pc and block._end >= instr.pc:
                block_instr = block
                break

        if not block_instr:
            raise ValueError("get_constraint_before_instr: block_instr not found")   

        reachable_block = nx.descendants(self.cfg.graph, block_instr)
        for reach_block in reachable_block:
            if reach_block in self.cfg.assignment_nodes:
                try:
                    reached_instr.extend(self.get_reachable_instr_in_block(instr, reach_block))
                except:
                    logger.error(f"{self.cfg._func_name} meet error in get reached instr, pc:{instr.pc}")
                    # set_trace()
                    # print(123)
        
        reached_instr.extend(self.get_reachable_instr_in_block(instr, block_instr, True))

        return reached_instr


    def get_constraint_before_instr(self, instr, block):
        """
            get the constraint before the instr
        """
        # # first, get corresponding block of instr
        # block_instr = None
        # # TODO: optimize the query process by add pc param
        # for _, block in self.cfg._block.items():
        #     if block._start <= instr.pc and block._end >= instr.pc:
        #         block_instr = block
        #         break

        # if not block_instr:
        #     raise ValueError("get_constraint_before_instr: block_instr not found")            
        
        # get the definition of definition_before_block
        definition_before_block = self.constraint_join(self.cfg.graph.predecessors(block)) 
        definition_before_instr = definition_before_block

        for pc, high_instr in block._high_instru.items():
            if high_instr == instr:
                break
            
            # TODO: CallInstr need consider?
            if (isinstance(high_instr, AssignmentInstr) and high_instr.in_closure == False) or \
                isinstance(high_instr, CallInstr): 
                # kill
                for i in range(len(high_instr.left_hand_side)):
                    left_hand_variable = high_instr.left_hand_side[i]
                    if check_lefthand_need_killed(high_instr, i):
                    # if check_definition_need_killed(high_instr):
                        definition_before_instr = self.arrow(definition_before_instr, left_hand_variable)
                
                # generation:
                definition_before_instr = definition_before_instr | self.lattice.el2bv[high_instr]

        return definition_before_instr

def do_RDA_analysis_recursively(cfg):
    # set_trace()
    logger.debug(f"do reaching definition analysis for func: {cfg._func_name}")
    cfg.RDA_analysis = RDA_Analysis(cfg)
    for index, sub_cfg in cfg.proto_func.items():
        do_RDA_analysis_recursively(sub_cfg)