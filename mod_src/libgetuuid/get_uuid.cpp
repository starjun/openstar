#include <stdio.h>
#include <string.h>
#ifdef __cplusplus
extern "C" {
#endif
        #include<lua.h>
        #include<lualib.h>
        #include<lauxlib.h>
#ifdef __cplusplus
}
#endif

#include "md5sum.h"
#include "common.h"
#include <string>

static int lib_getuuid(lua_State *L) {
    std::string serial_str = "";
    std::string uuid_str = "";
    std::string uuid_out = "";
    const char *salt = NULL;
    if (lua_gettop(L) == 1 && lua_isstring(L, 1)) {
        salt = luaL_checkstring(L, 1);
    }

    if (file_exist("/sys/class/dmi/id/product_serial")) {
        serial_str = get_file_content("/sys/class/dmi/id/product_serial");
    }
    if (file_exist("/sys/class/dmi/id/product_uuid")) {
        uuid_str = get_file_content("/sys/class/dmi/id/product_uuid");
    }
    if (serial_str.length() > 0 || uuid_str.length() > 0) {
        std::string ss = serial_str + uuid_str + (salt == NULL ? "" : salt);
        MD5Sum md5;
        md5.put(ss.c_str(), ss.length());
        uuid_out = md5.toString();
        md5_str_to_uuid_str(uuid_out);
    }

    lua_pushstring(L, uuid_out.c_str());
    return 1;
}

static luaL_Reg libs[] = {
    {"getuuid", lib_getuuid},
    {NULL, NULL}

};


extern "C" __attribute__ ((visibility("default"))) int luaopen_libgetuuid(lua_State *L) {
    const char *libName = "libgetuuid";
    luaL_register(L, libName, libs);
    // lua_newlib(L,libName,libs);
    // luaL_newlibtable(L,libName);
    // lubL_setfuncs(L,libs,0);
    return 1;
}

