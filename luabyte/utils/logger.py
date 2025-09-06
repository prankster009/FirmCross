import logging
import sys
import os

logger_dir_path = None

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
    
    # Create a logger
    logger_name = f'logger_{os.getpid()}_{name}'
    logger = logging.getLogger(logger_name)
    logger.setLevel(loglevel)
    
    # Create formatter
    formatter = logging.Formatter('%(asctime)s - %(name)40s - %(levelname)10s - %(funcName)40s - %(message)s')

    # Create handlers based on the log_to_file flag
    if log_to_file:
        # File handler for logging to a file
        global logger_dir_path
        if logger_dir_path:
            base_path = os.path.join(logger_dir_path, "log")
            # print(f"mkdir -p {base_path}")
            os.system(f"mkdir -p '{base_path}'")
            logger_file = os.path.join(base_path, log_filename)
        else:
            logger_file = log_filename
        if os.path.exists(logger_file):
            os.remove(logger_file)
        file_handler = logging.FileHandler(logger_file)
        file_handler.setLevel(loglevel)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    else:
        # Stream handler for logging to stdout
        stream_handler = logging.StreamHandler(sys.stdout)
        stream_handler.setLevel(loglevel)
        stream_handler.setFormatter(formatter)
        logger.addHandler(stream_handler)

    return logger