import threading
import time
import ctypes
from ipdb import set_trace

def terminate_thread(thread):
    """强制终止线程（高风险操作）"""
    if not thread.is_alive():
        return
    exc = ctypes.py_object(SystemExit)
    res = ctypes.pythonapi.PyThreadState_SetAsyncExc(
        ctypes.c_long(thread.ident), exc)
    if res == 0:
        raise ValueError("Thread not found")
    elif res > 1:
        ctypes.pythonapi.PyThreadState_SetAsyncExc(thread.ident, None)
        raise SystemError("Failed to terminate thread")

def run_with_timeout(func, args=(), timeout=300):
    """
    带超时控制的函数执行封装
    :param func: 目标函数
    :param args: 函数参数（元组格式）
    :param timeout: 超时时间（秒）
    :return: 函数正常执行的结果
    :raises TimeoutError: 超时异常
    """
    # 存储结果的线程安全容器
    result_container = []
    exception_container = []

    # 包装函数用于捕获执行结果
    def wrapper():
        try:
            result = func(*args)
            result_container.append(result)
        except Exception as e:
            exception_container.append(e)

    # 创建并启动线程
    target_thread = threading.Thread(target=wrapper)
    target_thread.daemon = True  # 主线程退出时自动终止
    target_thread.start()

    # 计算绝对超时时间点
    timeout_end = time.time() + timeout

    # 轮询监控线程状态
    while target_thread.is_alive():
        remaining = timeout_end - time.time()
        if remaining <= 0:
            terminate_thread(target_thread)
            target_thread.join(0.1)  # 清理线程资源
            raise TimeoutError(
                f"Function '{func.__name__}' timed out after {timeout} seconds")
        time.sleep(min(0.05, remaining))  # 动态调整轮询间隔

    # 处理执行结果
    if exception_container:
        raise exception_container[0]
    return result_container[0] if result_container else None