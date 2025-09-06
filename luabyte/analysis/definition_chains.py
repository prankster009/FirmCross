from collections import defaultdict


from .analysis import check_data_depend_instrs
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


def get_constraint_instr(
    cfg,
    instr,
    block
):
    constraint_before_instr = cfg.RDA_analysis.get_constraint_before_instr(instr, block)
    for n in cfg.RDA_analysis.lattice.get_elements(constraint_before_instr):
        if n is not instr:
            yield n

def build_def_use_chain(cfg):
    def_use = defaultdict(list)
    '''
        earlier_node: [node]  earlier_node is used by node
    '''
    # For every node
    for node in cfg.assignment_nodes:
        for _, high_instr in node._high_instru.items():
            if isinstance(high_instr, (AssignmentInstr, CallInstr)):
                # Loop through most of the nodes before it
                for earlier_instr in get_constraint_instr(cfg, high_instr, node):
                    if check_data_depend_instrs(high_instr, earlier_instr):
                        def_use[earlier_instr].append(high_instr)
    return def_use
    
