"""This formatter outputs the issues as plain text."""
from vulnerabilities.vulnerability_helper import SanitisedVulnerability
from vulnerabilities.source_sink_identify import Source_Instr_Trigger, Sink_Trigger, Sink_Trigger_Lua_Table_Func
from utils.logger import setup_logger
from ipdb import set_trace
import os
from analysis.analysis import clear_file_folder

# logger = setup_logger(__name__, log_to_file=True, log_filename='LuabyteTaint_report.log')
logger = setup_logger(__name__)


def report(
    vulnerabilities,
    fileobj,
    print_sanitised,
):
    """
    Prints issues in text format.

    Args:
        vulnerabilities: list of vulnerabilities to report
        fileobj: The output file object, which may be sys.stdout
        print_sanitised: Print just unsanitised vulnerabilities or sanitised vulnerabilities as well
    """
    n_vulnerabilities = len(vulnerabilities)
    unsanitised_vulnerabilities = [v for v in vulnerabilities if not isinstance(v, SanitisedVulnerability)]
    n_unsanitised = len(unsanitised_vulnerabilities)
    n_sanitised = n_vulnerabilities - n_unsanitised
    heading = "{} vulnerabilit{} found{}{}\n".format(
        'No' if n_unsanitised == 0 else n_unsanitised,
        'y' if n_unsanitised == 1 else 'ies',
        " (plus {} sanitised)".format(n_sanitised) if n_sanitised else "",
        ':' if n_vulnerabilities else '.',
    )
    vulnerabilities_to_print = vulnerabilities if print_sanitised else unsanitised_vulnerabilities
    with fileobj:
        fileobj.write(heading)

        for i, vulnerability in enumerate(vulnerabilities_to_print, start=1):
            fileobj.write('Vulnerability {}:\n{}\n\n'.format(i, vulnerability))

def report2(
    vulnerabilities
):
    """
    Prints issues in text format.

    Args:
        vulnerabilities: list of vulnerabilities to report
        fileobj: The output file object, which may be sys.stdout
        print_sanitised: Print just unsanitised vulnerabilities or sanitised vulnerabilities as well
    """
    n_vulnerabilities = len(vulnerabilities)
    unsanitised_vulnerabilities = [v for v in vulnerabilities if not isinstance(v, SanitisedVulnerability)]
    n_unsanitised = len(unsanitised_vulnerabilities)
    n_sanitised = n_vulnerabilities - n_unsanitised
    heading = "{} vulnerabilit{} found{}{}\n".format(
        'No' if n_unsanitised == 0 else n_unsanitised,
        'y' if n_unsanitised == 1 else 'ies',
        " (plus {} sanitised)".format(n_sanitised) if n_sanitised else "",
        ':' if n_vulnerabilities else '.',
    )
    vulnerabilities_to_print = vulnerabilities
    for i, vulnerability in enumerate(vulnerabilities_to_print, start=1):
        logger.debug('Vulnerability {}:\n{}\n\n'.format(i, vulnerability))


def report3(vulnerabilities, output_dir, sanitised=False):
    """
    Prints issues in text format.

    Args:
        vulnerabilities: list of vulnerabilities to report
        fileobj: The output file object, which may be sys.stdout
        print_sanitised: Print just unsanitised vulnerabilities or sanitised vulnerabilities as well
    """
    # set_trace()

    n_vulnerabilities = len(vulnerabilities)
    unsanitised_vulnerabilities = list()
    for vul in vulnerabilities:
        if len(vul.sanitized_info["True"]) and "command line arg" not in vul.source.trigger_word:
            unsanitised_vulnerabilities.append(vul)

    n_unsanitised = len(unsanitised_vulnerabilities)
    n_sanitised = n_vulnerabilities - n_unsanitised
    heading = "{} vulnerabilit{} found{}{}\n".format(
        'No' if n_unsanitised == 0 else n_unsanitised,
        'y' if n_unsanitised == 1 else 'ies',
        " (plus {} sanitised)".format(n_sanitised) if n_sanitised else "",
        ':' if n_vulnerabilities else '.',
    )
    if sanitised:
        vulnerabilities_to_print = unsanitised_vulnerabilities
    else:
        vulnerabilities_to_print = vulnerabilities
    
    
    vul_report_dir = os.path.join(output_dir, "vul_report_lua")
    if not os.path.exists(vul_report_dir):
        os.mkdir(vul_report_dir)
    else:
        clear_file_folder(vul_report_dir)
    
    lua_table_sink_dir = os.path.join(vul_report_dir, "lua_table_sink")
    if not os.path.exists(lua_table_sink_dir):
        os.mkdir(lua_table_sink_dir)
    else:
        clear_file_folder(lua_table_sink_dir)
    
    logger.info(heading)
    summary_file = os.path.join(vul_report_dir, "summary")
    with open(summary_file, "w+") as f:
        f.write(heading)
    
    for i, vulnerability in enumerate(vulnerabilities_to_print, start=1):
        # set_trace()
        if isinstance(vulnerability.sink, Sink_Trigger):
            source_module = os.path.basename(vulnerability.source.cfg.lua_module.module_name)
            source_func = vulnerability.source.cfg._func_name
            if "command line arg" in vulnerability.source.trigger_word:
                source_func = f"{source_func}({vulnerability.source.trigger_word})"
            sink_module = os.path.basename(vulnerability.sink.cfg.lua_module.module_name)
            sink_func = vulnerability.sink.cfg._func_name
            sink_trigger = vulnerability.sink_trigger_word
            sanitized = "True" if vulnerability in unsanitised_vulnerabilities else "sanitized"
            report_file_name = f"{i}:{sanitized}:{source_module}:{source_func}:{sink_module}:{sink_func}:{sink_trigger}"
            output_path = os.path.join(vul_report_dir,report_file_name)
        else:
            # Sink_Trigger_Lua_Table_Func
            source_module = os.path.basename(vulnerability.source.cfg.lua_module.module_name)
            source_func = vulnerability.source.cfg._func_name
            sink_module = os.path.basename(vulnerability.sink.cfg.lua_module.module_name)
            sink_func = vulnerability.sink.cfg._func_name
            sink_trigger = vulnerability.sink_trigger_word
            sanitized = "True" if vulnerability in unsanitised_vulnerabilities else "sanitized"
            report_file_name = f"{i}:Lua_Table:{vulnerability.sink.lib_name}|{vulnerability.sink.trigger_word}|{vulnerability.sink.param_idx}:{source_module}:{source_func}:{sink_module}:{sink_func}:{sink_trigger}"
            output_path = os.path.join(lua_table_sink_dir,report_file_name)
        vul_info = 'Vulnerability {}:\n{}\n\n'.format(i, vulnerability.get_all_chain_info(sanitised))
        # set_trace()
        logger.debug(vul_info)
        with open(output_path, "w+") as f:
            # max writing size: 5M
            max_size = 5 * 1024 * 1024
            if len(vul_info) > max_size:
                # 截断内容并添加截断提示
                truncated_info = vul_info[:max_size] + "\n\n[Content truncated, original data exceeds 5MB]"
            else:
                truncated_info = vul_info
            f.write(truncated_info)
        