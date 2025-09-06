import sys
sys.path.append("..")
from cfg.high_instruction import AssignmentInstr, CallInstr
from ipdb import set_trace
# from core.node_types import AssignmentNode


def get_lattice_elements(high_instrs):
    """Returns all assignment high instr as they are the only lattice elements
    in the reaching definitions analysis.
    """
    for inst in high_instrs:
        if isinstance(inst, CallInstr):
            yield inst
        if isinstance(inst, AssignmentInstr) and not inst.in_closure:
            yield inst

class Lattice:
    def __init__(self, RDA_Analysis, high_instrs):
        self.RDA_Analysis = RDA_Analysis
        self.el2bv = dict()  # Element to bitvector dictionary
        self.bv2el = list()  # Bitvector to element list
        for i, e in enumerate(get_lattice_elements(high_instrs)):
            # Give each element a unique shift of 1
            self.el2bv[e] = 0b1 << i
            self.bv2el.insert(0, e)

    def get_elements(self, number):
        if number == 0:
            return []

        elements = list()
        # Turn number into a binary string of length len(self.bv2el)
        binary_string = format(number,
                               '0' + str(len(self.bv2el)) + 'b')
        for i, bit in enumerate(binary_string):
            if bit == '1':
                elements.append(self.bv2el[i])
        return elements

    def in_constraint(self, node1, node2):
        """Checks if node1 is in node2's constraints
        For instance, if node1 = 010 and node2 = 110:
        010 & 110 = 010 -> has the element."""
        constraint = self.RDA_Analysis.constraint_table[node2]
        if constraint == 0b0:
            return False

        try:
            value = self.el2bv[node1]
        except KeyError:
            return False

        return constraint & value != 0
