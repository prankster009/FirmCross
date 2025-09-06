# FirmCross
FirmCross: Detecting Taint-style Vulnerabilities in Modern C-Lua Hybrid Web Services of Linux-based Firmware

## Install

We need to prepare two virtual python environments, corresponding to the Lua vulnerability detection and the C vulnerability detection respectively.

```shell
sudo apt install git
sudo apt install docker.io

cd firmcross_ae

python3.11 -m venv firmcross_ae_lua
source firmcross_ae_lua/bin/activate
pip install -r ./requirements.txt 
deactivate 

python3.11 -m venv firmcross_ae
source firmcross_ae/bin/activate
pip install -e ./mango-dfa/
pip install -e ./mango-dfa/pipeline/
sudo ./firmcross_ae/bin/mango-pipeline --build-docker
deactivate
```
## Usage

We use a test case to analyze a firmware instance, which allows us to get the results related to vulnerability detection, source identification, and cross-language data propagation detection.

Run the command bellow. 

```shell
cd firmcross/minimize_testcase/
sudo ./begin_vul_detection.sh
```

Within the `firmcross/minimize_testcase/result` directory, lots of files will get made to keep the analysis results. The functions of each file are as follows:

```text
├── cross_vul
    ├── API_vul: the cross-language vulnerability through API data propagation
    └── IPC_vul: the cross-language vulnerability through IPC data propagation
└── single_c: result of vulnerability detection for binary. The details are same as mango-dfa.
└── single_lua: result of vulnerability detection for lua script/bytecode        
    ├── log           
    │   └── LuabyteTaint.log         
    ├── lua_table: the libc functions that can be called by lua script/bytecpde
    │   └── lua_table 
    ├── Lua_to_C      
    │   └── IPC: the IPC/cmd exec triggered in lua
    ├── sink_identify 
    │   └── sink: the identified sinks       
    ├── source_identify:
    │   ├── event_handler: the identified URI handlers
    │   ├── fake_register: the fake registers which are filter out by firmcross
    │   ├── real_register: identified real URI registers
    │   └── source: identified lua source
    └── vul_report_lua: this directory contains many lua vulnerability report, and each report contains the def-use chains of the detected vulnerability. It should be noted that some vulnerability reports may have similar sources and sinks, so when counting the number of vulnerabilities, we will merge such vulnerabilities.
```
## Experiment Reproduction

To facilitate the reproduction of the experiments in the paper, we have released the artifact corresponding to the paper at [zenodo](https://doi.org/10.5281/zenodo.16950418).

## Citation

You can cite our paper as follows:

```
@inproceedings{ndss/FirmCross,
    author = {R. Liu, J. Dai, H. Xiao, Y. Zhang, Y. Mou, L. Xu, B. Yu, B. Wang,and M. Yang},
    title = {{FirmCross: Detecting Taint-Style Vulnerabilities in Modern C-Lua Hybrid Web Services of Linux-based Firmware}},
    booktitle = {{NDSS}},
    year = {2026}
}
```
## Refference

FirmCross is built on the [MangoDFA](https://github.com/sefcom/operation-mango-public) and [LuaDecompy](https://github.com/CPunch/LuaDecompy).