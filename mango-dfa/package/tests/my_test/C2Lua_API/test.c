#include <stdio.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

int main() {
    // 初始化Lua环境
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);

    if (luaL_loadfile(L, "script.lua") || lua_pcall(L, 0, 0, 0)) {
        // handle_lua_error(L, "加载 Lua 文件失败");
        lua_close(L);
        return 0;
    }

    lua_getglobal(L, "greet");       // 获取函数
    lua_pushstring(L, "Doubao");     // 参数

    if (lua_pcall(L, 1, 0, 0) != 0) {
        fprintf(stderr, "调用Lua函数失败: %s\n", lua_tostring(L, -1));
    }

    lua_close(L);
    return 0;
}
