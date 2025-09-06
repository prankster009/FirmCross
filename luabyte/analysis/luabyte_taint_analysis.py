import sys
sys.path.append("..")
from utils.logger import init_logger_path
from ipdb import set_trace
import time
import os
import traceback


def luabyte_taint_analysis(brand, squashfs_info, output_dir):
    # the init_logger_path must execute before import Whole_Module
    # print(f"init logger_path for {brand}: {output_dir}")
    init_logger_path(output_dir)

    image_id = squashfs_info["image_id"]
    product_id = squashfs_info["product_id"]
    fw_path = squashfs_info["rootfs_path"]

    # return {"brand":brand, "image_id": image_id, "product_id": product_id, "status": "success"}
    try:
        start_time = time.time()
        from analysis.module import Whole_Module
        # return {"brand":brand, "image_id": image_id, "product_id": product_id, "status": "success"}
        whole_module = Whole_Module(
                                    fw_path=fw_path, 
                                    output_dir=output_dir, 
                                    resolve_source=True, 
                                    is_vul_discover=True, 
                                    debug = False
                                )
        end_time = time.time()
        execution_time = end_time - start_time
        with open(os.path.join(output_dir, "usage_time"), "w+") as f:
            f.write(str(execution_time))
        return {"brand":brand, "image_id": image_id, "product_id": product_id, "status": "success", "usage_time": execution_time}
    except Exception as e:
        end_time = time.time()
        execution_time = end_time - start_time
        with open(os.path.join(output_dir, "usage_time"), "w+") as f:
            f.write(str(execution_time))
        error_info = traceback.format_exc()
        error_message = f"Error processing brand {brand} with image_id {image_id} and product_id {product_id}: {error_info}"
        return {"brand":brand, "image_id": image_id, "product_id": product_id, "status": "error", "error_message": str(error_info), "usage_time": execution_time}

def luabyte_taint_analysis_for_existing_method(product, fw_path, output_dir):
    # the init_logger_path must execute before import Whole_Module
    # print(output_dir)
    # print(fw_path)
    init_logger_path(output_dir)

    try:
        start_time = time.time()
        from analysis.module import Whole_Module
        whole_module = Whole_Module(
                                    fw_path=fw_path, 
                                    output_dir=output_dir, 
                                    resolve_source=True, 
                                    is_vul_discover=True, 
                                    debug = False
                                )
        end_time = time.time()
        execution_time = end_time - start_time
        with open(os.path.join(output_dir, "usage_time"), "w+") as f:
            f.write(str(execution_time))
        return {"product": product, "status": "success"}
    except Exception as e:
        end_time = time.time()
        execution_time = end_time - start_time
        with open(os.path.join(output_dir, "usage_time"), "w+") as f:
            f.write(str(execution_time))
        error_info = traceback.format_exc()
        error_message = f"Error processing product {product} : {error_info}"
        print(error_message)
        return {"product": product, "status": "error", "error_message": str(error_info)}