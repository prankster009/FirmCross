"""This module contains all of the Block High level instruction nodes types of CFG"""
from ipdb import set_trace

class BaseInstr():
    """A High level Instru node that represent the high level Semantics."""

    def __init__(self, pc, instruc_node):
        """Create a BaseNode that can be used in a High level Instruction.

        Args:
            instruc_node(Instruction): The Instruction instance
        """
        self.pc = pc
        self.instr = instruc_node

class AssignmentInstr(BaseInstr):
    """Instruction Node that represents an assignment."""

    def __init__(self, pc, left_hand_side, right_hand_side_variables, instruction, in_closure=False):
        """Create an Assignment node.

        Args:
            left_hand_side(str): The variable on the left hand side of the assignment. Used for analysis.
            right_hand_side_variables(list[str]): A list of variables on the right hand side.
            instruc_node(Instruction): The Instruction instance
        """
        super().__init__(pc, instruction)
        self.left_hand_side = left_hand_side
        self.right_hand_side_variables = right_hand_side_variables
        self.tainted = False # determine the left hand is tainted or not
        self.tainted_idx = list() # the tainted idx of left hand
        self.in_closure = in_closure 
    
    def toString(self):
        """
            print the info about the high level Assignment Instr
        """
        result_left = "["
        result_right = "["
        for variable in self.left_hand_side:
            if result_left != "[":
                result_left += ", "
            result_left += variable.toString()
        
        for variable in self.right_hand_side_variables:
            if result_right != "[":
                result_right += ", "
            result_right += variable.toString()
        
        result_left += "]"
        result_right += "]"
        final_result = f"left hand:  {result_left}" + "\n"
        final_result += f"right hand: {result_right}"
        return final_result

class CallInstr(BaseInstr):
    def __init__(self, pc, instruction, target, param_num, param_begin, return_num, return_begin, maxStack):
        """Create an Call node.

        Args:

        """
        super().__init__(pc, instruction)
        self.target = target # reg index of call target
        self.param_num = param_num # num if param num
        self.param_begin = param_begin # reg index of start that has param
        self.return_num = return_num # num of return value
        self.return_begin = return_begin # reg index of start to store return value
        self.maxStack = maxStack

        
        # create right hand(parameter)
        self.left_hand_side = list()
        self.right_hand_side_variables = list()
        if self.param_num != -1:
            for param_reg_idx in range(self.param_begin, self.param_begin+self.param_num):
                param_reg = create_reg(param_reg_idx)
                self.right_hand_side_variables.append(param_reg)
        else:
            # multi param
            for param_reg_idx in range(self.param_begin, self.maxStack):
                param_reg = create_reg(param_reg_idx)
                self.right_hand_side_variables.append(param_reg)

        # create left hand(return value)
        if self.return_num != -1:
            for return_reg_idx in range(self.return_begin, self.return_begin+self.return_num):
                return_reg = create_reg(return_reg_idx)
                self.left_hand_side.append(return_reg)
        else:
            # multi return
            for return_reg_idx in range(self.return_begin, self.maxStack):
                return_reg = create_reg(return_reg_idx)
                self.left_hand_side.append(return_reg)

class BranchInstr(BaseInstr):

    def __init__(self, pc, instruction):
        """Create an Assignment node.

        Args:
            left_hand_side(str): The variable on the left hand side of the assignment. Used for analysis.
            right_hand_side_variables(list[str]): A list of variables on the right hand side.
            instruc_node(Instruction): The Instruction instance
        """
        super().__init__(pc, instruction)

class OtherInstr(BaseInstr):

    def __init__(self, pc, instruction):
        """Create an Assignment node.

        Args:
            left_hand_side(str): The variable on the left hand side of the assignment. Used for analysis.
            right_hand_side_variables(list[str]): A list of variables on the right hand side.
            instruc_node(Instruction): The Instruction instance
        """
        super().__init__(pc, instruction)

Assign_OP_name = ["MOVE", "LOADK", "LOADBOOL", "LOADNIL", "GETUPVAL", "GETGLOBAL", "GETTABLE", "SETGLOBAL", "SETUPVAL", "SETTABLE", "CONCAT", "SETLIST", "SELF", "MOD"]

Branch_OP_name = ["EQ", "LT", "LE", "TEST", "TESTSET", "TFORLOOP", "FORLOOP", "JMP", "FORPREP"]

Call_OP_name = ["CALL", "TAILCALL"]

Other_OP_name = ["NEWTABLE", "ADD", "SUB", "MUL", "DIV", "POW", "UNM", "NOT", "LEN", "RETURN", "CLOSE", "CLOSURE", "VARARG"]

'''
the following class represents the object types of lua bytecodes 
'''
class Register():
    def __init__(self, Register_idx:int):
        self._idx = Register_idx
    
    def toString(self):
        return f"R[{self._idx}]"

class Global():
    def __init__(self, idx, sym:str):
        self._sym = sym
        self._idx = idx
    
    def toString(self):
        return f"Global[{self._sym}]"

class Upvalue():
    def __init__(self, Upvalue_idx:int):
        self._idx = Upvalue_idx

    def toString(self):
        return f"Upvalue[{self._idx}]"

class Table():
    def __init__(self, table_reg, table_idx):
        """
        table_reg: the reg that represent the table
        table_idx: the table element idx, either reg instance or constant instance or a int number
        """
        self._table_reg = table_reg
        self._table_idx = table_idx
    
    def toString(self):
        table_reg_str = self._table_reg.toString()
        if isinstance(self._table_idx, Register):
            table_idx_str = self._table_idx.toString()
        elif isinstance(self._table_idx, Constant):
            table_idx_str = self._table_idx.toString()
        elif isinstance(self._table_idx, int):
            table_idx_str = f"int_{self._table_idx}"
        
        return f"Table:reg_{table_reg_str} element_{table_idx_str}]"

class Constant():
    def __init__(self, Constant_idx, type, data):
        self._idx = Constant_idx
        self._type = type
        self._data = data
    
    def toString(self):
        return f"Constant_{self._data}(value)_{self._type}(type)"

class Concat():
    def __init__(self, data):
        self._data = data
    
    def toString(self):
        result = ""
        if self._data:
            for reg in self._data:
                if result:
                    result += " + "
                result += reg.toString()
            return result
        else:
            return "empty Concat"
        
def create_reg(idx):
    # create a Register instance according to idx
    return Register(idx)

def create_constant(idx, constant):
    return Constant(idx, constant.type, constant.data)

def create_upvalue(idx):
    return Upvalue(idx)

def create_global(idx, constant):
    if constant.type != 4:
        raise TypeError(f"Expected an constant string, but got type: {constant.type}, value: {constant.data}.")
    return Global(idx, constant.data)

def create_table(table_reg, element_idx):
    return Table(table_reg, element_idx)

def create_concat(concat_list):
    return Concat(concat_list)


def is_custom_class(obj):
    return not isinstance(obj, (int, str, list, dict, set, tuple, float, type(None)))

def Compare_instance(obj1, obj2):
    # check two instance class
    if type(obj1) is not type(obj2):
        return False

    
    try:
        # get the elements
        dict1 = vars(obj1)
        dict2 = vars(obj2)
    except:
        raise Exception("Compare_instance error")

    if dict1.keys() != dict2.keys():
        return False

    # Compare each attribute recursively
    for key in dict1:
        if is_custom_class(dict1[key]) and is_custom_class(dict2[key]):
            #  If the property is an object, call Compare_instance recursively
            # set_trace()
            if not Compare_instance(dict1[key], dict2[key]):
                return False
        else:
            if dict1[key] != dict2[key]:
                return False
    
    return True

def Depend_instance(obj1, obj2):
    """
        if obj1 is Table instance, we need check whether obj1 depends on obj2 or not
        e.g. obj1 = table.param, obj2 = table, then obj1 depends on obj2
    """
    if isinstance(obj1, Table) and isinstance(obj2, Register):
        table_reg = obj1._table_reg
        table_idx = obj1._table_idx

        if Compare_instance(table_reg, obj2):
            return True
        if Compare_instance(table_idx, obj2):
            return True
    return False



def get_high_level_instruction(pc, instruction, chunk, in_closure):
    """
    create the high level instruction instance according to the instruction.

    Args:
        instruction(Instruction): The Instruction instance
    """
    if instruction.name in Assign_OP_name:
        if instruction.name == "MOVE":
            # MOVE A B          R(A) := R(B)
            dst_reg = create_reg(instruction.A)
            src_reg = create_reg(instruction.B)
            left_hand = [dst_reg]
            right_hand = [src_reg]
            # the inclosure may be true in MOVE
            return AssignmentInstr(pc, left_hand, right_hand, instruction, in_closure), in_closure
        elif instruction.name == "LOADK":
            # LOADK A Bx        R(A) := Kst(Bx)
            in_closure = False
            dst_reg = create_reg(instruction.A)
            src_constant = create_constant(instruction.B, chunk.constants[instruction.B])
            left_hand = [dst_reg]
            right_hand = [src_constant]
            return AssignmentInstr(pc, left_hand, right_hand, instruction), in_closure
        elif instruction.name == "LOADBOOL":
            # LOADBOOL A B C    R(A) := (Bool)B; if (C) PC++ 
            in_closure = False
            dst_reg = create_reg(instruction.A)
            src_bool = True if instruction.B != 0 else False
            left_hand = [dst_reg]
            right_hand = [src_bool]
            return AssignmentInstr(pc, left_hand, right_hand, instruction), in_closure
        elif instruction.name == "LOADNIL":
            # LOADNIL A B       R(A) := ... := R(B) := nil
            in_closure = False
            left_hand = list()
            right_hand = list()
            for i in range(instruction.A, instruction.B+1):
                left_hand.append(create_reg(i))
                right_hand.append("nil")
            return AssignmentInstr(pc, left_hand, right_hand, instruction), in_closure
        elif instruction.name == "GETUPVAL":
            # GETUPVAL A B      R(A) := UpValue[B]
            dst_reg = create_reg(instruction.A)
            src_upvalue = create_upvalue(instruction.B)
            left_hand = [dst_reg]
            right_hand = [src_upvalue]
            # the inclosure may be true in GETUPVAL
            return AssignmentInstr(pc, left_hand, right_hand, instruction, in_closure), in_closure
        elif instruction.name == "SETUPVAL":
            # SETUPVAL A B      UpValue[B] := R(A)
            in_closure = False
            dst_upvalue = create_upvalue(instruction.B)
            src_reg = create_reg(instruction.A)
            left_hand = [dst_upvalue]
            right_hand = [src_reg]
            return AssignmentInstr(pc, left_hand, right_hand, instruction), in_closure
        elif instruction.name == "GETGLOBAL":
            # GETGLOBAL A Bx    R(A) := Gbl[Kst(Bx)]
            in_closure = False
            dst_reg = create_reg(instruction.A)
            src_global = create_global(instruction.B, chunk.constants[instruction.B])
            left_hand = [dst_reg]
            right_hand = [src_global]
            return AssignmentInstr(pc, left_hand, right_hand, instruction), in_closure
        elif instruction.name == "SETGLOBAL":
            # SETGLOBAL A Bx    Gbl[Kst(Bx)] := R(A)
            in_closure = False
            dst_global = create_global(instruction.B, chunk.constants[instruction.B])
            src_reg = create_reg(instruction.A)
            left_hand = [dst_global]
            right_hand = [src_reg]
            return AssignmentInstr(pc, left_hand, right_hand, instruction), in_closure
        elif instruction.name == "GETTABLE":
            # GETTABLE A B C    R(A) := R(B)[RK(C)]
            in_closure = False
            dst_reg = create_reg(instruction.A)
            table_reg = create_reg(instruction.B)
            element_idx = create_constant((instruction.C & ~(1 << 8)), chunk.constants[(instruction.C & ~(1 << 8))]) if (instruction.C & (1 << 8)) > 0 else create_reg(instruction.C)
            # element_idx = chunk.constants[(instruction.C & ~(1 << 8))] if (instruction.C & (1 << 8)) > 0 else create_reg(instruction.C)
            src_table = create_table(table_reg, element_idx)
            left_hand = [dst_reg]
            right_hand = [src_table]
            return AssignmentInstr(pc, left_hand, right_hand, instruction), in_closure
        elif instruction.name == "SETTABLE":
            # SETTABLE A B C    R(A)[RK(B)] := RK(C)
            in_closure = False
            table_reg = create_reg(instruction.A)
            element_idx = create_constant((instruction.B & ~(1 << 8)), chunk.constants[(instruction.B & ~(1 << 8))]) if (instruction.B & (1 << 8)) > 0 else create_reg(instruction.B)
            # element_idx = chunk.constants[(instruction.B & ~(1 << 8))] if (instruction.B & (1 << 8)) > 0 else create_reg(instruction.B)
            dst_table = create_table(table_reg, element_idx)
            src_element = create_constant((instruction.C & ~(1 << 8)), chunk.constants[(instruction.C & ~(1 << 8))] ) if (instruction.C & (1 << 8)) > 0 else create_reg(instruction.C)
            # src_element = chunk.constants[(instruction.C & ~(1 << 8))] if (instruction.C & (1 << 8)) > 0 else create_reg(instruction.C)
            left_hand = [dst_table]
            right_hand = [src_element]
            return AssignmentInstr(pc, left_hand, right_hand, instruction), in_closure
        elif instruction.name == "SETLIST":
            # SETLIST A B C     R(A)[(C-1)*FPF+i] := R(A+i), 1 <= i <= B
            in_closure = False
            table_reg = create_reg(instruction.A)
            left_hand = list()
            right_hand = list()
            for i in range(1, instruction.B+1):
                table_element_idx = (instruction.C-1)*50+i
                dst_table = create_table(table_reg, table_element_idx)
                left_hand.append(dst_table)
                src_reg = create_reg(instruction.A+i)
                right_hand.append(src_reg)
            return AssignmentInstr(pc, left_hand, right_hand, instruction), in_closure
        elif instruction.name == "CONCAT":
            # CONCAT A B C      R(A) := R(B).. ... ..R(C)
            in_closure = False
            dst_reg = create_reg(instruction.A)
            concat_list = list()
            for i in range(instruction.B, instruction.C+1):
                concat_list.append(create_reg(i))
            src_concat = create_concat(concat_list)
            left_hand = [dst_reg]
            right_hand = [src_concat]
            return AssignmentInstr(pc, left_hand, right_hand, instruction), in_closure
        elif instruction.name == "SELF":
            # SELF A B C        R(A+1) := R(B); R(A) := R(B)[RK(C)]
            in_closure = False
            dst_reg1 = create_reg(instruction.A+1)
            src_reg1 = create_reg(instruction.B)
            dst_reg2 = create_reg(instruction.A)
            element_idx = create_constant((instruction.C & ~(1 << 8)), chunk.constants[(instruction.C & ~(1 << 8))]) if (instruction.C & (1 << 8)) > 0 else create_reg(instruction.C)
            src_table = create_table(src_reg1, element_idx)
            left_hand = [dst_reg1, dst_reg2]
            right_hand = [src_reg1, src_table]
            return AssignmentInstr(pc, left_hand, right_hand, instruction), in_closure
        elif instruction.name == "MOD":
            # MOD A B C         R(A) := RK(B) % RK(C)
            # use CONCAT to model
            in_closure = False
            dst_reg = create_reg(instruction.A)
            concat_list = list()
            # only record reg which is not constant
            if (instruction.B & (1 << 8)) <= 0:
                src_reg_b = create_reg(instruction.B)
                concat_list.append(src_reg_b)
            if (instruction.C & (1 << 8)) <= 0:
                src_reg_c = create_reg(instruction.C)
                concat_list.append(src_reg_c)
            src_concat = create_concat(concat_list)
            left_hand = [dst_reg]
            right_hand = [src_concat]
            return AssignmentInstr(pc, left_hand, right_hand, instruction), in_closure
        else:
            raise TypeError(f"unexpected an Assignment OP Type, {instruction.name}.")
    elif instruction.name in Call_OP_name:
        if instruction.name == "CALL":
            # CALL A B C        R(A), ... ,R(A+C-2) := R(A)(R(A+1), ... ,R(A+B-1))
            # return value num: C-1, begin: R(A)
            # param num:        B-1, begin: R(A+1)
            in_closure = False
            target = instruction.A
            param_num = instruction.B - 1
            param_begin = instruction.A + 1
            return_num = instruction.C - 1
            return_begin = instruction.A
            return CallInstr(pc, instruction, target, param_num, param_begin, return_num, return_begin, chunk.maxStack), in_closure
        elif instruction.name == "TAILCALL":
            # TAILCALL A B C    return R(A)(R(A+1), ... ,R(A+B-1))
            in_closure = False
            target = instruction.A
            param_num = instruction.B - 1
            param_begin = instruction.A + 1
            return_num = -1 # represent multiple return results
            return_begin = instruction.A
            return CallInstr(pc, instruction, target, param_num, param_begin, return_num, return_begin, chunk.maxStack), in_closure
        else:
            raise TypeError(f"unexpected an Call OP Type, {instruction.name}.")
    elif instruction.name in Branch_OP_name:
        if instruction.name == "TFORLOOP":
            # TFORLOOP contain the call instr, which may have the data flow
            # so we treat the TFORLOOP as a CallInstr for RDA analysis and dataflow analysis
            
            # TFTOLOOP definition:
            #   TFORLOOP A C R(A+3), ... ,R(A+2+C) := R(A)(R(A+1), R(A+2)); 
            #   if R(A+3) ~= nil then {
            #       R(A+2) = R(A+3);
            #   } else {
            #       PC++;
            #   }

            # the right hand is R(A+1)---loop state. R(A)--generator, R(A+2)---enumeration index.
            # the left hand is R(A+4) -> R(A+C+2).   R(A+3) is the loop enumeration index.
            # details can be get form Lua 5.1 Instruction manual
            
            # TODO: create a unique class 
            in_closure = False
            target = instruction.A
            param_num = 2
            param_begin = instruction.A + 1
            return_num = instruction.C
            return_begin = instruction.A + 3
            tfotloop_callinstr = CallInstr(pc, instruction, target, param_num, param_begin, return_num, return_begin, chunk.maxStack)
            # as for tforloop, we need to change the left hand and right hand manually, just set them related to dataflow analysis.
            
            tfotloop_callinstr.right_hand_side_variables = [create_reg(instruction.A + 1)]
            tfotloop_callinstr.left_hand_side = list()
            for left_hand_reg_idx in range(instruction.A + 3 + 1, instruction.A + 3 + return_num):
                tfotloop_callinstr.left_hand_side.append(create_reg(left_hand_reg_idx))
            return tfotloop_callinstr, in_closure
        else:
            in_closure = False
            return BranchInstr(pc, instruction), in_closure
    elif instruction.name in Other_OP_name:
        if instruction.name == "CLOSURE":
            in_closure = True
            return OtherInstr(pc, instruction), in_closure
        else:
            in_closure = False
            return OtherInstr(pc, instruction), in_closure
    # TODO: return OP
