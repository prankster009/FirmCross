#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

// 定义一个简单的 C 函数，用于计算两个数的和
static int add(lua_State *L) {
    double a = luaL_checknumber(L, 1);
    double b = luaL_checknumber(L, 2);
    lua_pushnumber(L, a + b);
    return 1;
}

// 定义一个简单的 C 函数，用于打印字符串
static int print_string(lua_State *L) {
    const char *str = luaL_checkstring(L, 1);
    printf("%s\n", str);
    return 0;
}

// 定义要注册到 Lua 的函数列表
static const struct luaL_Reg mylib[] = {
    {"add", add},
    {"print_string", print_string},
    {NULL, NULL}
};

// 初始化库，将函数注册到 Lua
int luaopen_my_lua_lib(lua_State *L) {
    // luaL_newlib(L, mylib);
    luaL_register(L, "my_lua_lib", mylib);
    return 1;
}
