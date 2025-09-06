import os
import sys
sys.path.append("..")
from utils.database import Database
from ipdb import set_trace
from utils.logger import setup_logger
from .module import Whole_Module
import concurrent.futures
import json
import multiprocessing
import traceback
from collections import defaultdict
from typing import List, Dict, Tuple, Optional

logger = setup_logger(__name__)
# logger = setup_logger(__name__, log_to_file=False, log_filename='detect_source_large_scope.log')

"""
this file only use for middle test
and it is no use in the final
"""

def detect_source(brand, squashfs_info):
    image_id = squashfs_info["image_id"]
    product_id = squashfs_info["product_id"]
    rootfs_path = squashfs_info["rootfs_path"]
    try:
        whole_module = Whole_Module(rootfs_path)
        whole_module_source = whole_module.do_source_identify()
        current_path = "/home/nudt/lrh/first_work/luabyte_taint_larget_test_branch/source_result"
        brand_path = os.path.join(current_path, brand)
        if not os.path.exists(brand_path):
            os.makedirs(brand_path)
        file_name = f"image_id-{image_id}_product_id-{product_id}"
        file_path = os.path.join(brand_path, file_name)
        with open(file_path, "w") as f:
            json.dump(whole_module_source, f, indent=4)
        # set_trace()
        logger.debug(f"image_id:{image_id}, product_id:{product_id}, rootfs_path:{rootfs_path} finish")
        return {"image_id": image_id, "product_id": product_id, "status": "success"}
    except Exception as e:
        error_message = f"Error processing brand {brand} with image_id {image_id} and product_id {product_id}: {e}"
        logger.error(error_message)
        return {"image_id": image_id, "product_id": product_id, "status": "error", "error_message": str(e)}

def detect_source_test(brand, squashfs_info):
    image_id = squashfs_info["image_id"]
    product_id = squashfs_info["product_id"]
    rootfs_path = squashfs_info["rootfs_path"]
    try:
        # set_trace()
        whole_module = Whole_Module(rootfs_path)
        whole_module_source = whole_module.get_source_result()
        current_path = "/home/nudt/lrh/first_work/luabyte_taint_larget_test_branch/source_result"
        brand_path = os.path.join(current_path, brand)
        if not os.path.exists(brand_path):
            os.makedirs(brand_path)
        file_name = f"image_id-{image_id}_product_id-{product_id}"
        file_path = os.path.join(brand_path, file_name)
        
        # record info about source identify

        # record fake register
        fake_register_record = dict()
        for register_key, fake_handler_list in whole_module.fake_register.items():         
            event_handler_name = list()
            for handler in fake_handler_list:
                module_name = handler.lua_module.module_name
                func_name = handler._func_name
                handler_name = f"{module_name}:{func_name}"
                event_handler_name.append(handler_name)            
            fake_register_record[register_key] = event_handler_name

        with open(f"{file_path}_fake_register", "w") as f:
            json.dump(fake_register_record, f, indent=4)

        
        # record real register
        with open(f"{file_path}_real_register", "w") as f:
            for register_name, register_info in whole_module.final_register.items():
                for info in register_info:
                    param_idx = info['param_idx']
                    f.write(f"{register_name}:{param_idx}\n")
            f.write("\n")
        
        # record event handler with param tainted
        event_handler = defaultdict(int)
        for register_name, Source_Identify_list in whole_module.source_identify.items():
            for source_identify in Source_Identify_list:
                key = f"{register_name}:{source_identify.register_param_idx}"
                
                value = dict()
                value["param"] = list(source_identify.nested_access["param"].keys())
                
                event_handler_name = list()
                for handler in source_identify.event_handler:
                    module_name = handler.lua_module.module_name
                    func_name = handler._func_name
                    handler_name = f"{module_name}:{func_name}"
                    event_handler_name.append(handler_name)
                value["handler"] = event_handler_name
                
                event_handler[key] = value
        
        with open(f"{file_path}_event_handler",'w') as f:
            json.dump(event_handler, f, indent=4)

        logger.debug(f"image_id:{image_id}, product_id:{product_id}, rootfs_path:{rootfs_path} finish")
        return {"image_id": image_id, "product_id": product_id, "status": "success"}
    except Exception as e:
        error_info = traceback.format_exc()
        error_message = f"Error processing brand {brand} with image_id {image_id} and product_id {product_id}: {error_info}"
        logger.error(error_message)

        return {"image_id": image_id, "product_id": product_id, "status": "error", "error_message": str(error_info)}