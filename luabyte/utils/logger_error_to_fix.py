import logging
import sys
import os

logger_dir_path = None
_logger_configured = False

def init_logger_path(output_path):
    global logger_dir_path
    logger_dir_path = output_path
    default_logger_file = os.path.join(logger_dir_path, "LuabyteTaint.log")
    if os.path.exists(default_logger_file):
        os.system(f"rm {default_logger_file}")

def setup_logger(name, log_to_file=True, log_filename='LuabyteTaint.log', level=1):
    """
    Set up logger to log either to stdout or to a file based on the log_to_file argument.
    
    :param log_to_file: If True, logs will be written to a file. If False, logs will be written to stdout.
    :param log_filename: The name of the file where logs will be stored, used only if log_to_file is True.
    :return: logger instance.
    """
    if level == 0:
        loglevel = logging.DEBUG
    elif level == 1:
        loglevel = logging.INFO
    else:
        loglevel = logging.INFO
    

    # Create formatter
    formatter = logging.Formatter('%(asctime)s - %(name)40s - %(levelname)10s - %(funcName)40s - %(message)s')

    # 仅首次调用时配置Handler
    global _logger_configured
    if not _logger_configured:
        # Create a logger
        root_logger = logging.getLogger()
        root_logger.setLevel(logging.DEBUG)
        # 清除可能存在的旧处理器
        for handler in root_logger.handlers[:]:
            root_logger.removeHandler(handler)

        # Create handlers based on the log_to_file flag
        if log_to_file:
            # File handler for logging to a file
            global logger_dir_path
            if logger_dir_path:
                base_path = os.path.join(logger_dir_path, "log")
                os.system(f"mkdir -p {base_path}")
                logger_file = os.path.join(base_path, log_filename)
            else:
                logger_file = log_filename

            handler = logging.FileHandler(logger_file, mode='w')
            
        else:
            # Stream handler for logging to stdout
            handler = logging.StreamHandler(sys.stdout)
        
        handler.setLevel(logging.DEBUG)
        handler.setFormatter(formatter)
        root_logger.addHandler(handler)
        _logger_configured = True
    
    return_logger = logging.getLogger(name)
    return_logger.setLevel(loglevel)
    # 将根日志记录器的处理器复制到返回的日志记录器中
    for handler in logging.getLogger().handlers:
        return_logger.addHandler(handler)

    return return_logger