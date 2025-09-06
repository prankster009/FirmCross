import sys
import os
sys.path.append("..")
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
from .constraint_table import (
    constraint_join,
    constraint_table
)
# from .constant_propagation import get_callee_name, get_concrete_value
from ipdb import set_trace

def check_lefthand_need_killed(high_instr: AssignmentInstr|CallInstr, left_hand_idx):
    """
        check if the left hand definition of AssignmentInstr or CallInstr instance, high_instr, need to be killed
        e.g. a = concat a, b, c . the a definition still alive, becase the left a depends on right a

        high_instr: AssignmentInstr or CallInstr
    """
    # two situation

    # first situation: Call Instr, all the pre left hand definition need to be killed
    # because the return value|left hand is from the function call
    if isinstance(high_instr, CallInstr):
        return True

    # second situation: AssignmentInstr, the left hand and right hand correspond one to one
    # get the left hand and right hand variable
    right_hand = high_instr.right_hand_side_variables
    if left_hand_idx >= len(right_hand):
        # the left hand is more than right hand
        # e.g. the high instr of Param Block
        return True
    else:
        right_variable = right_hand[left_hand_idx]
        left_variable = high_instr.left_hand_side[left_hand_idx]

        if isinstance(right_variable, Concat):
            reg_concat_dst = left_variable
            for src_reg in right_variable._data:
                if Compare_instance(reg_concat_dst, src_reg):
                    return False
        else:
            if Compare_instance(left_variable, right_variable) or \
                Depend_instance(left_variable, right_variable):
                return False
                
    return True

def check_definition_need_killed(high_instr: AssignmentInstr|CallInstr):
    """
        check if the left hand definition of AssignmentInstr or CallInstr instance need to be killed
        e.g. a = concat a, b, c . the a definition still alive, becase the left a depends on right a

        high_instr: AssignmentInstr or CallInstr
    """

    left_hand = high_instr.left_hand_side
    right_hand = high_instr.right_hand_side_variables
    
    # TODO: SETLIST special case, may can not be return immediately
    for i in range(len(high_instr.right_hand_side_variables)):
        try:
            # TODO: call instr need to be consider carefully becasue it have more left and right hand, and there are relationship between them.
            left_variable = left_hand[i]
            right_variable = right_hand[i]
        except:
            if isinstance(high_instr, CallInstr):
                # In CallInstr, the num of left hand and right hand is not equal
                break
        if isinstance(right_variable,Concat):
            reg_concat_dst = left_variable
            for src_reg in right_variable._data:
                if Compare_instance(reg_concat_dst, src_reg):
                    return False
        else:
            if Compare_instance(left_variable, right_variable) or \
                Depend_instance(left_variable, right_variable):
                return False
                
    return True

def check_data_depend_instrs(instr1, instr2, instr2_left_hand_reg_idx=None):
    """
        check whether the dataflow of instr1 depends on instr2
    """
    for idx, left_object in enumerate(instr2.left_hand_side):
        if instr2_left_hand_reg_idx:
            if not isinstance(left_object, Register) or left_object._idx != instr2_left_hand_reg_idx:
                continue
        for right_object in instr1.right_hand_side_variables:
            # special case: Concat
            if isinstance(right_object, Concat):
                for src_reg in right_object._data:
                    if Compare_instance(left_object, src_reg) or Depend_instance(src_reg, left_object):
                        return True
            # if left_object == right_object, then add
            # if right_object depend on left_object, then add
            # e.g. left_object = table, right_object = table.param, then right_object is depend on left_object
            elif Compare_instance(left_object, right_object) or Depend_instance(right_object, left_object):
                return True


def get_block_contain_pc(cfg, pc):
    # block_instr = None
    for _, block in cfg._block.items():
        if block._start <= pc and block._end >= pc:
            return block
    return None


def clear_file_folder(folder_path):
    if os.path.exists(folder_path) and os.path.isdir(folder_path):
        for item in os.listdir(folder_path):
            item_path = os.path.join(folder_path, item)
            if os.path.isfile(item_path):
                os.remove(item_path)

def determine_ruijie_fw(squashfs_path):
    pass

def extract_values(dictionary):
    values = []
    for value in dictionary.values():
        if isinstance(value, dict):
            # 如果值是字典，递归调用函数
            values.extend(extract_values(value))
        else:
            values.append(value)
    return values







                        