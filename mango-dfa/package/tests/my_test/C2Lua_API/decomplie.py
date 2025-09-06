import angr

def decompile_function(binary_path, function_identifier):
    """
    反编译二进制文件中的指定函数
    
    参数:
        binary_path: 二进制文件路径
        function_identifier: 函数名或函数地址(整数)
    """
    # 加载二进制文件
    project = angr.Project(binary_path, auto_load_libs=False)
    
    # 确定目标函数
    if isinstance(function_identifier, str):
        # 通过函数名查找
        try:
            function = project.kb.functions[function_identifier]
            print(f"反编译函数: {function_identifier} (地址: 0x{function.addr:x})")
        except KeyError:
            print(f"错误: 找不到函数 '{function_identifier}'")
            return
    else:
        # 通过地址查找
        function = project.kb.functions.get(function_identifier)
        if function is None:
            print(f"错误: 地址 0x{function_identifier:x} 处没有函数")
            return
        print(f"反编译函数: 地址 0x{function_identifier:x}")
    
    # 执行反编译
    decompiler = project.analyses.Decompiler(function)
    
    # 检查反编译是否成功
    if decompiler.codegen:
        # 获取类似C语言的伪代码
        decompiled_code = str(decompiler.codegen)
        return decompiled_code
    else:
        print("反编译失败，可能是因为函数过于复杂或存在不支持的指令")
        return None

if __name__ == "__main__":
    binary_path = "./test"  # 替换为实际的二进制文件路径
    function_name = "main"  # 替换为要反编译的函数名
    
    decompiled_code = decompile_function(binary_path, function_name)
    if decompiled_code:
        print("\n反编译结果:\n")
        print(decompiled_code)
