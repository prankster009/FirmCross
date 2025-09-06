#!/bin/bash

# 指定Lua文件目录
# directory="/home/iot_2204/xiaomi/Xiaomi_4_Pro_Stable_1.0.31/squashfs-root/usr/lib/lua" 
# directory="./test_case/ruijie_RG-EW3200GX/"
directory="/home/nudt/lrh/first_work/TOTOLink/"

# 遍历指定目录下的所有 Lua 文件
find "$directory" -type f -name "*.lua" | while read lua_file; do
    # 为每个文件运行 lua ChunkSpy51.lua xxx.lua -o xxx.lst
    output_file="${lua_file%.lua}.lst"  # 输出文件名以 .lst 结尾
    echo "Processing: $lua_file -> $output_file"
    lua /home/iot_2204/lua_analysis/luadec/ChunkSpy/ChunkSpy51.lua "$lua_file" -o "$output_file"
done
