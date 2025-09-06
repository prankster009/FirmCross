"""
    constant propagation analysis
"""
import sys
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
from cfg.cfg import CFG
from ipdb import set_trace
import copy
from enum import Enum
import time
from utils.logger import setup_logger
import re
debug = True
from .analysis import get_block_contain_pc

logger = setup_logger(__name__)


# 定义枚举类
class ConstantType(Enum):
    NAC = "NAC"
    Constant = "Constant"
    Undefined = "Undefined"
    Table = "Table"

class ConstantRegister:
    """
        represent the constant info of the target reg
    """
    def __init__(self, index:int, constant_type:str, value=None):
        self.index = index # the register index 
        self.type = constant_type # Constant/NAC/Undefined
        self.value = value # constant value
        
    def __eq__(self, other):
        if isinstance(other, ConstantRegister):
            return self.index == other.index and self.type == other.type and self.value == other.value
        return False

def compare_two_constant_table(table1, table2):
    if not isinstance(table1, dict) or not isinstance(table2, dict):
        return False
    if set(table1.keys()) != set(table2.keys()):
        return False
    for key in table1:
        """
            two value possiblity:
                1. tuple: (type, value)
                2. TABLE: dict
        """
        table_value1 = table1[key]
        table_value2 = table2[key]
        if isinstance(table_value1, tuple) and isinstance(table_value2, tuple):
            type1, value1 = table_value1
            type2, value2 = table_value2
            if type1 == type2:
                if type1 == ConstantType.Constant:
                    # str, load_module, cfg, int, float
                    # TODO: consider carefully, because the cfg and load_module need to point to the same obj
                    # so, we need not to compare the vars in load_module and cfg
                    if isinstance(value1, (Load_Module, CFG)) and isinstance(value2, (Load_Module, CFG)):
                        if not vars(value1) == vars(value2):
                            return False
                    else:
                        if not value1 == value2:
                            return False
                if type1 == ConstantType.NAC:
                    continue
                if type1 == ConstantType.Table:
                    if not compare_two_constant_table(value1, value2):
                        return False
            else:
                return False
        else:
            raise Exception("unexpected constant table value")
    return True

def compare_constant_table_list(table_list):
    
    if len(table_list) == 1:
        return True
    # set_trace()
    first_table = table_list[0]
    for i, table_instance in enumerate(table_list):
        if not i:
            continue
        if not compare_two_constant_table(first_table.value, table_instance.value):
            return False
    return True

class ConstantCollect:
    def __init__(self):
        self.NAC = list()
        self.Undefined = list()
        self.Constant = list()
        self.Table = list()

class Load_Module:
    def __init__(self, custom, module_list):
        self.is_module_custom = custom # does the func call start with require
        self.module_list = module_list

def change_constant(constant_list, idx, type, value=None):
    # if idx == 15 and value == "/home/ftp.name":
    #     set_trace()
    target_constant = constant_list[idx]
    if target_constant.index != idx:
        raise Exception("constant index dismatch")
    target_constant.type = type
    target_constant.value = value

def assign_NAC_to_return_regs(constant_list, return_begin_reg_idx, return_num):
    # do not deal with the situation of no return value or multi return value
    if return_num > 0:
        for i in range(return_num):
            change_constant(constant_list, return_begin_reg_idx+i, ConstantType.NAC)

def get_constant_info_of_RK(constant_list, RK):
    """
        RK: register or constant

        return three possbility:
            TABLE
                dict
            Constant
                str
                Load_Module
                CFG
            NAC
    """
    type = ConstantType.NAC
    value = ""
    if isinstance(RK, Register):
        element_reg_idx = RK._idx
        constant_of_element_reg_idx = get_constant(constant_list, element_reg_idx)
        if constant_of_element_reg_idx.type == ConstantType.Constant:
            # str, Load_Module, CFG
            type = ConstantType.Constant
            value = constant_of_element_reg_idx.value
        elif constant_of_element_reg_idx.type == ConstantType.Table:
             type = ConstantType.Table
             value = constant_of_element_reg_idx.value
        else:
            type = ConstantType.NAC    
    elif isinstance(RK, Constant):
        if RK._type == 4: #string
            type = ConstantType.Constant
            value = RK._data
        elif RK._type == 3: #number
            type = ConstantType.Constant
            value = str(RK._data)
        else:
            type = ConstantType.NAC
    else:
        type = ConstantType.NAC
    return type, value

def get_constant(constant_list, idx):
    constant = constant_list[idx]
    if constant.index != idx:
        raise Exception("constant index dismatch")
    return constant

def get_string_from_format(reverse_record_chains):
    """
        get string from string.format function
        such as:  string.format([[/usr/bin/ether-wake -b -i %s %s]], l, string.gsub(r, "-", ":"))
    """
    # set_trace()
    for record in reverse_record_chains:
        reverse_chain = record.use_chain[::-1]
        for i, used_instr in enumerate(reverse_chain):
            if isinstance(used_instr, CallInstr):
                func_reg_idx = used_instr.target
                param_num = used_instr.param_num
                param_begin = used_instr.param_begin
                if param_num == 0:
                    continue
                current_cfg = record.cfg
                pc = used_instr.pc
                block = get_block_contain_pc(current_cfg, pc)
                callee_name = get_callee_name(current_cfg, block, pc, func_reg_idx)
                if callee_name and isinstance(callee_name, str) and "format" in callee_name:
                    first_param_value = get_concrete_value(current_cfg, block, pc, param_begin)
                    if isinstance(first_param_value, str):
                        return first_param_value
        return "string.format not find"

def get_callee_name(cfg, block, pc, reg_idx):
    callee_name = None
    constant_value = get_concrete_value(cfg, block, pc, reg_idx)
    if isinstance(constant_value, Load_Module):
        callee_name = ".".join(constant_value.module_list)
    elif isinstance(constant_value, str):
        callee_name = constant_value
    elif isinstance(constant_value, CFG):
        try:
            callee_name = constant_value._func_name
        except:
            callee_name = "unknow_func_name"
    
    return callee_name


def get_concrete_value(cfg:CFG, block, pc, reg_idx):
    """
        get the callee in the block with pc, in the cfg

        return: constant_value or None
    """
    constant_list = cfg.constant_propagation.get_constant_before_pc(block, pc)
    constant_instance = get_constant(constant_list, reg_idx)
    if constant_instance.type == ConstantType.Constant:
        return constant_instance.value
    else:
        return None


def compare_two_instance_of_contant_type(instance1, instance2):
    if instance1.type != ConstantType.Constant or \
        instance2.type != ConstantType.Constant:
        raise Exception("use compare_two_instance_of_contant_type func error")
    if instance1.index == instance2.index:
        if instance1.type == instance2.type:
            value1 = instance1.value
            value2 = instance2.value
            if isinstance(value1, Load_Module) and isinstance(value2, Load_Module):
                return vars(value1) == vars(value2)
            else:
                return value1 == value2
    return False

def compare_two_constant_list(list1, list2):
    for idx, constant in enumerate(list1):
        constant1 = list1[idx]
        constant2 = list2[idx]
        if constant1.type == constant2.type:
            if constant1.type == ConstantType.Constant:
               if not compare_two_instance_of_contant_type(constant1, constant2):
                    # print("constant")
                    # set_trace()
                    #print(constant1.value.__dict__)
                    # print(constant2.value.__dict__)
                    return False
            elif constant1.type == ConstantType.Table:
                if not compare_two_constant_table(constant1.value, constant1.value):
                    # print("Table")
                    # print(constant1.value)
                    # print(constant2.value)
                    return False
        else:
            # print(constant1.__dict__)
            # print(constant2.__dict__)
            # print("consistent type not equal")
            return False
    return True

class ConstantPropagation:
    """
        there are four types of constant:
            undefined
            NAC
            Constant
            Table
        
        Constant:
            type: ConstantType.Constant
            value: 
                str, int, float  ----> LOADK, GETGLOBAL  
                Load_Module, initial from call like instr
                CFG, initial from closure
        
        Table:
            type: ConstantType.Table
            value: dict, {
                            "element_str": (type, value)
                            }
                
                the type in tuple has three possibility:
                    1. NAC, value is no use
                    2. Constant, value is same as Constant.value
                    3. Table, value is dict

    """
    def __init__(self, cfg):
        self.cfg = cfg
        self.constant_table = dict()
        self.load_global_sym = list() # this is for SETTABLE used in assigning value to global var
        self.init_constant_table()
        self.fixpoint_runner()
        self.propage_upvale()
        # if self.cfg._func_name == "dns_check_domain_conflict" and self.cfg.lua_module.module_name == "/home/iot_2204/lua_analysis/Luabyte_Taint/test_case/test4/switch.luac":
        #     logger.debug("constant info:\n" + self.get_constant_info())
        #     set_trace()
        #     self.cfg.draw_cfg()
        
        # if self.cfg._func_name == "dns_check_domain_conflict":
        #     logger.debug("constant info:\n" + self.get_constant_info())
        #     set_trace()
    
    def print_constant(self):
        """
            print constant of every block of cfg
        """
        print(f"file_name:{self.cfg.lua_module.module_name}")
        print(f"func_name:{self.cfg._func_name}")
        nodes = list(self.cfg.graph.nodes())
        for node in nodes:
            # set_trace()
            print(f"block_instr: {node._start}")
            for constant in self.constant_table[node]:
                if constant.type == ConstantType.Constant:
                    print(f"    R{constant.index}:{constant.value}")

    def get_constant_info(self):
        """
            get constant of every block of cfg
        """
        content = ""
        content += f"file_name:{self.cfg.lua_module.module_name}" + "\n"
        content += f"func_name:{self.cfg._func_name}" + "\n"
        nodes = list(self.cfg.graph.nodes())
        for node in nodes:
            # set_trace()
            content += f"block_instr: {node._start}" + "\n"
            for constant in self.constant_table[node]:
                if constant.type == ConstantType.Constant:
                    content += f"    R{constant.index}:{constant.value}" + "\n"
        return content

    def get_undefined_constant_list(self):
        register_num = self.cfg._chunk.maxStack
        constant_object_list = list()
        for i in range(register_num):
            constant_object_list.append(ConstantRegister(i, ConstantType.Undefined))
        return constant_object_list

    def init_constant_table(self):
        initial_constant_object_list = self.get_undefined_constant_list()
        self.constant_table.update(dict.fromkeys(self.cfg.graph.nodes(), initial_constant_object_list))

    def join(self, node_list_target):
        # convert generator to list
        node_list_target = list(node_list_target)
        result_constant_list = self.get_undefined_constant_list()
        for reg_idx, constant in enumerate(result_constant_list):
            constant_collect = ConstantCollect()
            for cfg_node in node_list_target:
                constant_list = self.constant_table[cfg_node]
                reg_constant = constant_list[reg_idx]
                if reg_constant.type == ConstantType.NAC:
                    constant_collect.NAC.append(reg_constant)
                elif reg_constant.type == ConstantType.Constant:
                    constant_collect.Constant.append(reg_constant)
                elif reg_constant.type == ConstantType.Undefined:
                    constant_collect.Undefined.append(reg_constant)
                elif reg_constant.type == ConstantType.Table:
                    constant_collect.Table.append(reg_constant)
                    
            if constant_collect.NAC:
                constant.type = ConstantType.NAC
            elif constant_collect.Constant:
                if constant_collect.Table:
                    constant.type = ConstantType.NAC
                else:
                    isconsist = True
                    fisr_constant = None
                    for c in constant_collect.Constant:
                        if fisr_constant == None:
                            # init value
                            fisr_constant = c
                            continue
                        else:
                            if not compare_two_instance_of_contant_type(fisr_constant, c):
                                isconsist = False
                                break
                    if isconsist == True:
                        constant.type = ConstantType.Constant
                        constant.value = fisr_constant.value
                    else:
                        constant.type = ConstantType.NAC
            elif constant_collect.Table:
                isconsist = compare_constant_table_list(constant_collect.Table)
                if isconsist:
                    table_instance = constant_collect.Table[0]
                    constant.type = ConstantType.Table
                    constant.value = table_instance.value
                else:
                    constant.type = ConstantType.NAC
        return result_constant_list

    def constant_propagation_one_pc(self, arrow_constant_list, in_closure, high_instr):
        Arithmetic_and_String_Instructions = ["ADD", "SUB", "MUL", "DIV", "POW", "UNM", "NOT", "LEN"]
        if isinstance(high_instr, AssignmentInstr): 
            if not high_instr.instr:
                # this is a param node
                pass
            elif high_instr.instr.name == "LOADK":
                in_closure = False
                left_reg = high_instr.left_hand_side[0]
                reg_idx = left_reg._idx
                right_variable = high_instr.right_hand_side_variables[0]
                constant_value = right_variable._data
                change_constant(arrow_constant_list, reg_idx, ConstantType.Constant, constant_value)
            elif high_instr.instr.name == "LOADNIL":
                in_closure = False
                left_reg = high_instr.left_hand_side[0]
                reg_idx = left_reg._idx
                change_constant(arrow_constant_list, reg_idx, ConstantType.Constant, "")
            elif high_instr.instr.name == "LOADBOOL":
                in_closure = False
                left_reg = high_instr.left_hand_side[0]
                reg_idx = left_reg._idx
                bool_value = high_instr.right_hand_side_variables[0]
                change_constant(arrow_constant_list, reg_idx, ConstantType.Constant, str(bool_value))
            elif high_instr.instr.name == "GETGLOBAL":
                in_closure = False
                left_reg = high_instr.left_hand_side[0]
                reg_idx = left_reg._idx
                right_global = high_instr.right_hand_side_variables[0]
                global_sym = right_global._sym
                if global_sym not in self.load_global_sym:
                    self.load_global_sym.append(global_sym)
                # resolve the content of global_sym if exist
                # set_trace()
                if global_sym in self.cfg.lua_module.global_var:
                    global_sym = self.cfg.lua_module.global_var[global_sym]
                if isinstance(global_sym, dict):
                    change_constant(arrow_constant_list, reg_idx, ConstantType.Table, global_sym)
                else:
                    change_constant(arrow_constant_list, reg_idx, ConstantType.Constant, global_sym)
            elif high_instr.instr.name == "MOVE":
                # move after closure does not propagate constant
                if not in_closure:
                    left_reg = high_instr.left_hand_side[0]
                    reg_idx = left_reg._idx
                    right_reg = high_instr.right_hand_side_variables[0]
                    right_reg_idx = right_reg._idx
                    constant_of_right_reg_idx = get_constant(arrow_constant_list, right_reg_idx)
                    change_constant(arrow_constant_list, reg_idx, \
                                            constant_of_right_reg_idx.type, constant_of_right_reg_idx.value)
            elif high_instr.instr.name == "CONCAT":
                in_closure = False
                type = ConstantType.Constant
                value = ""
                right_concat = high_instr.right_hand_side_variables[0]
                if right_concat._data:
                    for reg in right_concat._data:
                        src_reg_idx = reg._idx
                        constant_of_src_reg_idx = get_constant(arrow_constant_list, src_reg_idx)
                        if constant_of_src_reg_idx.type == ConstantType.Constant:
                            if isinstance(constant_of_src_reg_idx.value, (int, float)):
                                value += str(int(constant_of_src_reg_idx.value))
                            elif isinstance(constant_of_src_reg_idx.value, str):
                                value += constant_of_src_reg_idx.value
                            else:
                                # Load_Module, CFG
                                type = ConstantType.NAC
                                break
                        else:
                            type = ConstantType.NAC
                            break
                else:
                    type = ConstantType.NAC
                left_reg = high_instr.left_hand_side[0]
                reg_idx = left_reg._idx
                change_constant(arrow_constant_list, reg_idx, type, value)
            elif high_instr.instr.name == "SETTABLE":
                # if high_instr.pc == 8:
                #     set_trace()
                # SETTABLE A B C        R(A)[RK(B)] := RK(C)
                in_closure = False
                right_element = high_instr.right_hand_side_variables[0]
                src_type, src_value = get_constant_info_of_RK(arrow_constant_list, right_element)
                
                left_table = high_instr.left_hand_side[0]

                left_table_reg = left_table._table_reg
                left_table_reg_idx = left_table_reg._idx
                constant_of_table_reg_idx = get_constant(arrow_constant_list, left_table_reg_idx)

                left_table_element = left_table._table_idx
                element_type, element_value = get_constant_info_of_RK(arrow_constant_list, left_table_element)

                if element_type == ConstantType.Constant and isinstance(element_value, str):
                    # if element_value == "__index" and self.cfg.lua_module.module_name == "/home/iot_2204/lua_analysis/Luabyte_Taint/test_case/test5/luci/torchlight/httpclient.luac":
                    # if self.cfg.lua_module.module_name == "/home/iot_2204/lua_analysis/Luabyte_Taint/test_case/test5/luci/torchlight/httpclient.luac":
                    #     # set_trace()
                    #     print("SETTABLE info")
                    #     print(constant_of_table_reg_idx.value)
                    #     print(src_type, src_value)
                        # set_trace()
                    if constant_of_table_reg_idx.type == ConstantType.Table:
                        table_dict = constant_of_table_reg_idx.value
                    else:
                        table_dict = dict()
                    
                    is_table_reg_constant_str = False
                    if constant_of_table_reg_idx.type == ConstantType.Constant and \
                        isinstance(constant_of_table_reg_idx.value, str):

                        is_table_reg_constant_str = True
                        table_reg_str = constant_of_table_reg_idx.value

                    # Three possbility: 
                    #   Constant,
                    #   Table
                    #   NAC
                    if table_dict is not src_value:
                        """
                        sometimes, the dict in lua may point to itself
                        e.g.:
                            httpclient.lua in tplink R470 GP
                            dut = {}
                            dut.__index = dut
                            slp_maker = {}
                            slp_maker.__index = slp_maker
                        """
                        table_dict[element_value] = (src_type, src_value) 
                        change_constant(arrow_constant_list, left_table_reg_idx, ConstantType.Table, table_dict)
                    
                    # the settable may assign value to global var
                    if is_table_reg_constant_str:
                        if table_reg_str in self.load_global_sym:
                            # set_trace()
                            self.cfg.lua_module.global_var[table_reg_str] = table_dict
                else:
                    if constant_of_table_reg_idx.type != ConstantType.Table:
                        change_constant(arrow_constant_list, left_table_reg_idx, ConstantType.NAC)
            elif high_instr.instr.name == "GETTABLE":
                # GETTABLE A B C        R(A) := R(B)[RK(C)]
                in_closure = False
                right_variable = high_instr.right_hand_side_variables[0]
                table_reg = right_variable._table_reg
                element_idx = right_variable._table_idx
                type = ConstantType.NAC
                value = ""
                
                # check table reg value
                table_reg_idx = table_reg._idx
                constant_of_table_reg_idx = get_constant(arrow_constant_list, table_reg_idx)
                table_reg_value = constant_of_table_reg_idx.value

                if constant_of_table_reg_idx.type == ConstantType.Table:
                    if isinstance(table_reg_value, dict):
                        element_type, element_value = get_constant_info_of_RK(arrow_constant_list, element_idx)
                        if element_type == ConstantType.Constant and isinstance(element_value, str):
                            if element_value in table_reg_value:
                                type, value = table_reg_value[element_value]
                            else:
                                type = ConstantType.NAC
                        else:
                            type = ConstantType.NAC
                    else:
                        type = ConstantType.NAC
                elif constant_of_table_reg_idx.type == ConstantType.Constant:

                    element_type, element_value = get_constant_info_of_RK(arrow_constant_list, element_idx)
                    if element_type == ConstantType.Constant and isinstance(element_value, str):
                        if isinstance(table_reg_value, str):
                            type = ConstantType.Constant
                            value = f"{table_reg_value}.{element_value}"
                        elif isinstance(table_reg_value, Load_Module):
                            type = ConstantType.Constant
                            """
                                # determine if the Load_Module has duplicated path
                                e.g.

                                local function a(n, t)
                                    local e = 0
                                    local r = 1
                                    local d = #t
                                    while true do
                                        r = n:find(t)  ----------------------> loop
                                        if r == nil then
                                            break
                                        end
                                        n = n:sub(r + d) ---------------------> loop
                                        e = e + 1
                                    end
                                    return e
                                end
                            """
                            module_list = table_reg_value.module_list
                            need_add = False
                            for new_path in element_value.split("."):
                                if new_path not in module_list:
                                    need_add = True
                            if need_add:
                                load_module_copy = copy.deepcopy(table_reg_value)
                                load_module_copy.module_list.extend(element_value.split("."))
                                value = load_module_copy
                            else:
                                load_module_copy = copy.deepcopy(table_reg_value)
                                value = load_module_copy
                        else:
                            type = ConstantType.NAC
                    else:
                        type = ConstantType.NAC
                else:
                    if table_reg_idx <= self.cfg._chunk.numParams:
                        """
                            --dns.lua
                            function dns_check_domain_conflict(i, c, e)
                                local n = false
                                i:foreach("dns", c, function(i) --------> special case, i:foreach
                                    if e ~= nil and string.upper(e) == string.upper(i.domain) then
                                        n = true
                                        return
                                    end
                                end)
                                return n
                            end

                            e.g.: get set delete foreach commit etc
                        """
                        value = f"Param_{table_reg_idx}"
                        element_type, element_value = get_constant_info_of_RK(arrow_constant_list, element_idx)
                        if element_type == ConstantType.Constant and isinstance(element_value, str):
                            type = ConstantType.Constant
                            value = f"{value}.{element_value}"
                        else:
                            type = ConstantType.NAC
                    else:
                        type = ConstantType.NAC

                left_reg = high_instr.left_hand_side[0]
                reg_idx = left_reg._idx
                change_constant(arrow_constant_list, reg_idx, type, value)
            elif high_instr.instr.name == "GETUPVAL":
                if not in_closure:
                    # set_trace()
                    upvalue_index = high_instr.instr.B
                    upvalue_constant = self.cfg.upvalue[upvalue_index]
                    dst_reg_idx = high_instr.instr.A
                    change_constant(arrow_constant_list, dst_reg_idx, upvalue_constant.type, upvalue_constant.value)
            elif high_instr.instr.name == "SETGLOBAL":
                in_closure = False
                # record the value of global var, which point to a module
                # SETGLOBAL A Bx        Gbl[Kst(Bx)] := R(A)
                # set_trace()
                
                dst_global = high_instr.left_hand_side[0]
                src_reg = high_instr.right_hand_side_variables[0]
                src_reg_idx = src_reg._idx
                src_reg_constant = get_constant(arrow_constant_list, src_reg_idx)
                if src_reg_constant.type == ConstantType.Constant:
                    if isinstance(src_reg_constant.value, (Load_Module, CFG)):
                        self.cfg.lua_module.global_var[dst_global._sym] = src_reg_constant.value
                elif src_reg_constant.type == ConstantType.Table:
                    # set_trace()
                    if isinstance(src_reg_constant.value, dict):
                        self.cfg.lua_module.global_var[dst_global._sym] = src_reg_constant.value
            elif high_instr.instr.name == "SELF":
                # if self.cfg._func_name == "func_unknow_0_6" and \
                #     self.cfg.lua_module.module_name == "/home/iot_2204/lua_analysis/Luabyte_Taint/test_case/test5/luci/ip.luac" :
                #     set_trace()


                in_closure = False
                # SELF A B C            R(A+1) := R(B); R(A) := R(B)[RK(C)]

                # R(A+1) := R(B) (same as MOVE)
                left_reg = high_instr.left_hand_side[0]
                reg_idx = left_reg._idx
                right_reg = high_instr.right_hand_side_variables[0]
                right_reg_idx = right_reg._idx
                constant_of_right_reg_idx = get_constant(arrow_constant_list, right_reg_idx)
                change_constant(arrow_constant_list, reg_idx, \
                                        constant_of_right_reg_idx.type, constant_of_right_reg_idx.value)
                
                # R(A) := R(B)[RK(C)] (same as GETTABLE)
                right_variable = high_instr.right_hand_side_variables[1]
                table_reg = right_variable._table_reg
                element_idx = right_variable._table_idx
                type = ConstantType.NAC
                value = ""
                
                # check table reg value
                table_reg_idx = table_reg._idx
                constant_of_table_reg_idx = get_constant(arrow_constant_list, table_reg_idx)
                table_reg_value = constant_of_table_reg_idx.value

                if constant_of_table_reg_idx.type == ConstantType.Table:
                    if isinstance(table_reg_value, dict):
                        element_type, element_value = get_constant_info_of_RK(arrow_constant_list, element_idx)
                        if element_type == ConstantType.Constant and isinstance(element_value, str):
                            if element_value in table_reg_value:
                                type, value = table_reg_value[element_value]
                            else:
                                type = ConstantType.NAC
                        else:
                            type = ConstantType.NAC
                    else:
                        type = ConstantType.NAC
                elif constant_of_table_reg_idx.type == ConstantType.Constant:

                    element_type, element_value = get_constant_info_of_RK(arrow_constant_list, element_idx)
                    if element_type == ConstantType.Constant and isinstance(element_value, str):
                        if isinstance(table_reg_value, str):
                            type = ConstantType.Constant
                            value = f"{table_reg_value}.{element_value}"
                        elif isinstance(table_reg_value, Load_Module):
                            type = ConstantType.Constant
                            """
                                # determine if the Load_Module has duplicated path
                                e.g.

                                local function a(n, t)
                                    local e = 0
                                    local r = 1
                                    local d = #t
                                    while true do
                                        r = n:find(t)  ----------------------> loop
                                        if r == nil then
                                            break
                                        end
                                        n = n:sub(r + d) ---------------------> loop
                                        e = e + 1
                                    end
                                    return e
                                end
                            """
                            
                            module_list = table_reg_value.module_list
                            need_add = False
                            for new_path in element_value.split("."):
                                if new_path not in module_list:
                                    need_add = True
                            if need_add:
                                load_module_copy = copy.deepcopy(table_reg_value)
                                load_module_copy.module_list.extend(element_value.split("."))
                                value = load_module_copy
                            else:
                                load_module_copy = copy.deepcopy(table_reg_value)
                                value = load_module_copy
                            
                        else:
                            type = ConstantType.NAC
                    else:
                        type = ConstantType.NAC
                else:
                    if table_reg_idx <= self.cfg._chunk.numParams:
                        """
                            --dns.lua
                            function dns_check_domain_conflict(i, c, e)
                                local n = false
                                i:foreach("dns", c, function(i) --------> special case, i:foreach
                                    if e ~= nil and string.upper(e) == string.upper(i.domain) then
                                        n = true
                                        return
                                    end
                                end)
                                return n
                            end

                            e.g.: get set delete foreach commit etc
                        """
                        value = f"Param_{table_reg_idx}"
                        element_type, element_value = get_constant_info_of_RK(arrow_constant_list, element_idx)
                        if element_type == ConstantType.Constant and isinstance(element_value, str):
                            type = ConstantType.Constant
                            value = f"{value}.{element_value}"
                        else:
                            type = ConstantType.NAC
                    else:
                        type = ConstantType.NAC
                left_reg = high_instr.left_hand_side[1]
                reg_idx = left_reg._idx
                change_constant(arrow_constant_list, reg_idx, type, value)
            else:
                # TODO: left OP: SETUPVAL, SETLIST, MOD
                pass

        elif isinstance(high_instr, CallInstr):
            in_closure = False
            # if high_instr.pc == 2 and self.cfg._func_name == "cli_init":
            #     set_trace()
            if high_instr.instr.name == "CALL":
                call_target_idx = high_instr.target
                call_target_reg_constant = get_constant(arrow_constant_list, call_target_idx)

                if call_target_reg_constant.type != ConstantType.Constant:
                    # assign Constant.NAC for return reg
                    return_begin_reg_idx = high_instr.return_begin
                    return_num = high_instr.return_num
                    assign_NAC_to_return_regs(arrow_constant_list, return_begin_reg_idx, return_num)
                else:
                    constant_func = call_target_reg_constant.value
                    if isinstance(constant_func, str):
                        if constant_func == "require":
                            # deal with require("xxx")
                            is_require_situation = False
                            param_num = high_instr.param_num
                            if param_num == 1:
                                param_begin_reg_idx = high_instr.param_begin
                                param_begin_reg_constant = get_constant(arrow_constant_list, param_begin_reg_idx)
                                if param_begin_reg_constant.type == ConstantType.Constant and \
                                    isinstance(param_begin_reg_constant.value, str):
                                    
                                    param_constant_str = param_begin_reg_constant.value
                                    return_num = high_instr.return_num
                                    
                                    if return_num == 1:
                                        is_require_situation = True
                                        return_begin_reg_idx = high_instr.return_begin
                                        module_list = param_constant_str.split(".")
                                        func_return = Load_Module(True, module_list)
                                        change_constant(arrow_constant_list, return_begin_reg_idx, ConstantType.Constant, func_return)
                            
                            if not is_require_situation:
                                # assign Constant.NAC for return reg
                                return_begin_reg_idx = high_instr.return_begin
                                return_num = high_instr.return_num
                                assign_NAC_to_return_regs(arrow_constant_list, return_begin_reg_idx, return_num)
                        else:
                            """
                                local t = io.popen("df", "r")
                                local e = t:read("*l") --> make this right

                                a, c = io.open(t.file_name, "r")

                                local t = tostring(xxx)
                                local e = t:sub(xxx) --> make this right

                                local e = ubus.connect()
                                local n = e:call("tddpServer", "getInfo", { infoMask = 1023 }) --> make this right
                            """
                            param_num = high_instr.param_num
                            return_num = high_instr.return_num
                            # if return_num == 1 or return_num == 2 or return_num == -1:
                            if return_num != 0:
                                """
                                    a, c = io.open(t.file_name, "r")  , return_num = 2
                                    t.fork_call(string.format("echo '%s' > %s 2>/dev/null", a, i)), string.format->return_num == -1
                                """
                                constant_func = call_target_reg_constant.value
                                module_list = constant_func.split(".")
                                func_return = Load_Module(False, module_list)
                                return_begin_reg_idx = high_instr.return_begin
                                if return_num != -1:
                                    for return_reg_idx in range(return_begin_reg_idx, return_begin_reg_idx+return_num):
                                        change_constant(arrow_constant_list, return_reg_idx, ConstantType.Constant, func_return)
                                else:
                                    for return_reg_idx in range(return_begin_reg_idx, self.cfg._chunk.maxStack):
                                        change_constant(arrow_constant_list, return_reg_idx, ConstantType.Constant, func_return)
                            else:
                                # assign Constant.NAC for return reg
                                return_begin_reg_idx = high_instr.return_begin
                                return_num = high_instr.return_num
                                assign_NAC_to_return_regs(arrow_constant_list, return_begin_reg_idx, return_num)

                    elif isinstance(constant_func, Load_Module):
                        """
                            # situaiton: require(xxxx).xxxx
                            # e.g. require("luci.model.uci").cursor()
                            # so, require("luci.model.uci").cursor().get() can be resolve
                        """
                        return_begin_reg_idx = high_instr.return_begin
                        change_constant(arrow_constant_list, return_begin_reg_idx, ConstantType.Constant, constant_func)
                    else:
                        # CFG, this need not to propagate constant 
                        # set_trace()
                        return_begin_reg_idx = high_instr.return_begin
                        return_num = high_instr.return_num
                        assign_NAC_to_return_regs(arrow_constant_list, return_begin_reg_idx, return_num)
            else:
                # TAILCALL OP will not used to requre("xxx")
                # TODO: consider carefully, TAILCALL need not to be considered in constant propagation
                pass
        elif high_instr.instr.name == "CLOSURE":
            in_closure = True
            # only for func call
            reg_idx = high_instr.instr.A
            sub_proto_num = high_instr.instr.B
            sub_proto = self.cfg.proto_func[sub_proto_num]
            change_constant(arrow_constant_list, reg_idx, ConstantType.Constant, sub_proto)
        elif high_instr.instr.name in Arithmetic_and_String_Instructions:
            # treat the left hand of these op as NAC constant
            # ADD A B C R(A) := RK(B) + RK(C)
            # SUB A B C R(A) := RK(B) – RK(C)
            # MUL A B C R(A) := RK(B) * RK(C)
            # DIV A B C R(A) := RK(B) / RK(C)
            # MOD A B C R(A) := RK(B) % RK(C)
            # POW A B C R(A) := RK(B) ^ RK(C)
            # UNM A B R(A) := -R(B)
            # NOT A B R(A) := not R(B)
            # LEN A B R(A) := length of R(B)
            in_closure = False
            reg_idx = high_instr.instr.A
            change_constant(arrow_constant_list, reg_idx, ConstantType.NAC)
        elif high_instr.instr.name == "NEWTABLE":
            # NEWTABLE A B C        R(A) := {} (size = B,C)
            in_closure = False
            reg_idx = high_instr.instr.A
            empty_dict = dict()
            change_constant(arrow_constant_list, reg_idx, ConstantType.Table, empty_dict)
        else:
            in_closure = False
        """
        the below instructions has not been model, may be little useful for constant analysis
        Branch_OP_name = ["TESTSET", "TFORLOOP", "FORLOOP", "FORPREP"]
        Other_OP_name = ["RETURN", "VARARG"]
        """
        return arrow_constant_list, in_closure




    def fixpointmethod(self, cfg_node):
        # this is used for get function name of call-like instr
        # get the func parameter string
        # get the global variable table containing the constant

        # join
        in_closure = False
        arrow_constant_list = self.join(self.cfg.graph.predecessors(cfg_node))
        for pc, high_instr in cfg_node._high_instru.items():
            # print(pc)
            # kill and generate
            arrow_constant_list, in_closure = self.constant_propagation_one_pc(arrow_constant_list, in_closure, high_instr)

        self.constant_table[cfg_node] = arrow_constant_list

    def fixpoint_runner(self):
        """Work list algorithm that runs the fixpoint algorithm."""
        q = list(self.cfg.graph.nodes())

        timeout = 5 * 60 # 超时时间（秒）
        start_time = time.time()  # 记录开始时间

        # if self.cfg._func_name == "_modify_ipsec_conns_for_l2tp":
        #     self.cfg.draw_cfg()
        #     set_trace()
        num = 0
        while q != []:
            if self.cfg._func_name == "root_func" and \
                "flow_old_cfg_to_new" in self.cfg.lua_module.module_name:
                break
            # set_trace()
            if time.time() - start_time > timeout:
                # special case to resolve: flow_old_cfg_to_new.luac in ruijie ruijie_RG-EW3200GX
                break
            # if self.cfg._func_name == "root_func" and q[0]._start == 17:
            #     set_trace()
            x_i = self.constant_table[q[0]]  # x_i = q[0].old_constraint
            self.fixpointmethod(q[0])  # y = F_i(x_1, ..., x_n);
            y = self.constant_table[q[0]]  # y = q[0].new_constraint

            new_add_node = []
            if not compare_two_constant_list(y, x_i):
                # print(self.cfg._func_name)
                # print(self.cfg.lua_module.module_name)
                # print(q[0].__dict__)
                num += 1
                # if self.cfg._func_name == "func_unknow_0_6" and self.cfg.lua_module.module_name == "/home/iot_2204/lua_analysis/Luabyte_Taint/test_case/test5/luci/ip.luac":
                #     set_trace()
                #     self.cfg.draw_cfg()

                # if self.cfg._func_name == "root_func" and \
                #     "flow_old_cfg_to_new" in self.cfg.lua_module.module_name:
                #     # set_trace()
                #     # self.cfg.draw_cfg()
                #     with open("constant_info", "a", encoding="utf-8") as file:
                #         # file.write("这是追加的内容\n")
                #         current_node = q[0]
                #         file.write(f"block info: begin:{current_node._start}, end:{current_node._end}\n")
                #         file.write("old info \n")
                #         for constant in x_i:
                #             file.write(str(constant.__dict__)+"\n")
                #         file.write("\nnew info \n")
                #         for constant in y:
                #             file.write(str(constant.__dict__)+"\n")
                #         for idx, constant in enumerate(x_i):
                #             if not vars(x_i[idx]) == vars(y[idx]):
                #                 file.write(f"{idx}, {vars(x_i[idx]) == vars(y[idx])}"+"\n")
                        #set_trace()
                
                for node in self.cfg.graph.successors(q[0]):  # for (v in dep(v_i))
                    new_add_node.append(node)
                self.constant_table[q[0]] = y  # q[0].old_constraint = q[0].new_constraint # x_i = y
            
            # add new node at the list begin.
            q = q[1:]
            for node in new_add_node:
                if node in q:
                    q.remove(node)
            q = new_add_node + q
            
            del x_i


    def get_constant_before_pc(self, block, pc_target):
        """
            get the constant info before the instr whose pc is pc , in the block
        """
        in_closure = False
        arrow_constant_list = self.join(self.cfg.graph.predecessors(block))
        for pc, high_instr in block._high_instru.items():
            if pc == pc_target:
                break
            # kill and generate
            arrow_constant_list, in_closure = self.constant_propagation_one_pc(arrow_constant_list, in_closure, high_instr)
        return arrow_constant_list
        

    def propage_upvale(self):
        logger.debug(f"assign upvalue for sub func of {self.cfg._func_name}")
        # after basic constant propagation, we propagate upvalue to sub proto func
        cfg_nodes = list(self.cfg.graph.nodes())
        in_closure = False
        closure_id = -1
        upvalue_idx = 0
        for node in cfg_nodes:
            for pc, high_instr in node._high_instru.items():
                if not high_instr.instr:
                    # this is a param node
                    continue
                if high_instr.instr.name == "CLOSURE":
                    in_closure = True
                    closure_id = high_instr.instr.B
                    upvalue_idx = 0
                elif high_instr.instr.name == "MOVE":
                    if in_closure:
                        constant_list = self.get_constant_before_pc(node, pc)
                        upvalue_reg_idx = high_instr.instr.B
                        upvalue_reg_constant = copy.copy(get_constant(constant_list, upvalue_reg_idx))
                        # try:
                            
                        #     upvalue_reg_constant = copy.copy(get_constant(constant_list, upvalue_reg_idx))
                        # except:
                            
                        #     constant = get_constant(constant_list, upvalue_reg_idx)
                        #     cfg_obj = constant.value
                        #     print(dir(cfg_obj))  # 查看对象的所有属性和方法
                        #     for attr in dir(cfg_obj):
                        #         if not attr.startswith('__'):
                        #             print(f"{attr}: {getattr(cfg_obj, attr)}")
                        #     set_trace()
                        del constant_list
                        # propagate upvalue to sub func
                        sub_proto_cfg = self.cfg.proto_func[closure_id]
                        sub_proto_cfg.upvalue[upvalue_idx] = upvalue_reg_constant
                        upvalue_idx = upvalue_idx + 1
                elif high_instr.instr.name == "GETUPVAL":   
                    if in_closure:
                        upvalue_index = high_instr.instr.B
                        upvalue_constant = self.cfg.upvalue[upvalue_index]
                        # propagate upvalue to sub func
                        sub_proto_cfg = self.cfg.proto_func[closure_id]
                        sub_proto_cfg.upvalue[upvalue_idx] = upvalue_constant
                        upvalue_idx = upvalue_idx + 1
                else:
                    in_closure = False
                    upvalue_idx = 0
