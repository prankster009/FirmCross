#!/usr/bin/env python3
import sys
from utils.logger import init_logger_path

if len(sys.argv) != 3:
    print("Usage: python script.py squashfs_path output_dir")
    sys.exit(1)

fw_path = sys.argv[1]
output_dir = sys.argv[2]

# the init_logger_path must execute before import Whole_Module
init_logger_path(output_dir)

from analysis.identify_lua_table import get_lua_table
get_lua_table(fw_path, output_dir)