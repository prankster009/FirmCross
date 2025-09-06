import claripy
from ipdb import set_trace

def get_pointer_addr(project, addr, size):
    # set_trace()
    endness = "little" if "Iend_LE" == project.arch.memory_endness else "big"
    addr_bytes = project.loader.memory.load(addr, size)
    addr = int.from_bytes(addr_bytes, byteorder=endness, signed=False)
    
    return addr

def get_string(project, addr):
    # 初始化一个空的字节列表用于存储读取到的字节
    str_bytes = bytearray()

    # 从指定地址开始逐个字节读取，直到遇到 \0 字符
    current_addr = addr
    while True:
        byte = project.loader.memory.load(current_addr, 1)
        if byte[0] == 0:  # 检查是否为 \0 字符
            break
        str_bytes.extend(byte)
        current_addr += 1

    # 将字节数据转换为字符串
    final_str = str_bytes.decode('utf-8', errors='ignore')
    return final_str

def get_lua_register_table(project, table_addr, addr_size):
    # 初始化一个空列表来存储函数名和地址
    functions = []
    while True:     
        # 读取函数名地址
        # name_addr_bytes = project.loader.memory.load(table_addr, addr_size)
        # name_addr = project.loader.memory.unpack_bytes(name_addr_bytes, endness=project.arch.memory_endness)
        name_addr = get_pointer_addr(project, table_addr, addr_size)

        # 如果函数名地址为 0，说明表已经结束
        if name_addr == 0:
            break

        # # 读取函数名
        # name_bytes = project.loader.memory.load(name_addr, 32)  # 假设函数名最大长度为 32 字节
        # name = project.loader.memory.unpack_bytes(name_bytes, endness=project.arch.memory_endness)
        # # 将字节数据转换为字符串，去除空字符
        # name_str = name.decode('utf-8').rstrip('\x00')
        name_str = get_string(project, name_addr)

        # 读取函数地址
        # func_addr_bytes = project.loader.memory.load(table_addr + addr_size, addr_size)
        # func_addr = project.loader.memory.unpack_bytes(func_addr_bytes, endness=project.arch.memory_endness)
        func_addr = get_pointer_addr(project, table_addr + addr_size, addr_size)

        # 将函数名和地址添加到列表中
        functions.append((name_str, func_addr))

        # 移动到下一个表项
        table_addr += 2 * addr_size

    return functions
