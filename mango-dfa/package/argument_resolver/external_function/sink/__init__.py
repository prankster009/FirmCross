from .sink_lists import (
    COMMAND_INJECTION_SINKS,
    PATH_TRAVERSAL_SINKS,
    STRING_FORMAT_SINKS,
    BUFFER_OVERFLOW_SINKS,
    ENV_SINKS,
    GETTER_SINKS,
    SETTER_SINKS,
    STRCAT_SINKS,
    MEMCPY_SINKS,
    Sink,
    LUA_REGISTER_SINKS,
    C2Lua_API_SINK,
)

VULN_TYPES = {
    "cmdi": COMMAND_INJECTION_SINKS,
    "path": PATH_TRAVERSAL_SINKS,
    "strfmt": STRING_FORMAT_SINKS,
    "overflow": BUFFER_OVERFLOW_SINKS,
    "strcat": STRCAT_SINKS,
    "env": ENV_SINKS,
    "getter": GETTER_SINKS,
    "setter": SETTER_SINKS,
    "memcpy": MEMCPY_SINKS,
    "lua_register": LUA_REGISTER_SINKS,
    "c2lua_api": C2Lua_API_SINK,
}
