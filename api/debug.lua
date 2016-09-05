
local headers = ngx.req.get_headers()
local host = ngx.unescape_uri(headers["Host"])
local method = ngx.var.request_method
local args = ngx.req.get_uri_args() or {}
local url = ngx.unescape_uri(ngx.var.uri)
local request_url = ngx.unescape_uri(ngx.var.request_uri)
local remoteIp = ngx.var.remote_addr
local lua_version


local config_dict = ngx.shared.config_dict

local cjson_safe = require "cjson.safe"
local config_base = cjson_safe.decode(config_dict:get("base")) or {}

local optl = require("optl")

--- 判断config_dict中模块开关是否开启
local function config_is_on(config_arg)
    if config_base[config_arg] == "on" then
        return true
    end
end

--- 取config_dict中的json数据
local function getDict_Config(Config_jsonName)
    local re = cjson_safe.decode(config_dict:get(Config_jsonName)) or {}
    return re
end

--- remath(str,re_str,options)
--- 常用二阶匹配规则
local remath = optl.remath

-- 传入 (host)
local function loc_getRealIp(_host)
    if config_is_on("realIpFrom_Mod") then
        local realipfrom = getDict_Config("realIpFrom_Mod")
        local ipfromset = realipfrom[_host]
        if type(ipfromset) ~= "table" then return remoteIp end
        if remath(remoteIp,ipfromset.ips[1],ipfromset.ips[2]) then
            local x = 'http_'..ngx.re.gsub(tostring(ipfromset.realipset),'-','_')
            local ip = ngx.unescape_uri(ngx.var[x])
            return ip
        else
            return remoteIp
        end
    else
        return remoteIp
    end
end

local get_postargs = optl.get_posts

if jit then 
    lua_version = jit.version
else 
    lua_version = _VERSION
end
local debug_tb = {
    _Openstar_version = config_base.openstar_version,
    _pid = ngx.worker.pid(),
    _worker_count =ngx.worker.count(),
    _worker_id = ngx.worker.id(),
    _ngx_configure=ngx.config.nginx_configure(),
    _ngx_prefix=ngx.config.prefix(),
    _lua_version = lua_version,
    _ngx_lua_version = ngx.config.ngx_lua_version,
    _url = url,
    _method = method,
    _request_url = request_url,
    _args = args,
    _headers = headers,
    _schema = ngx.var.schema,
    _var_host = ngx.var.host,
    _hostname = ngx.var.hostname,
    _servername = ngx.var.server_name or "unknownserver",
    _remoteIp = remoteIp,
    _ip = loc_getRealIp(host,headers),
    _filename = ngx.var.request_filename,
    _query_string = ngx.unescape_uri(ngx.var.query_string),
    _nowtime=ngx.var.time_local or "time error",
    _remote_addr = ngx.var.remote_addr,
    _remote_port = ngx.var.remote_port,
    _remote_user = ngx.var.remote_user,
    _remote_passwd = ngx.var.remote_passwd,
    _content_type = ngx.var.content_type,
    _content_length = ngx.var.content_length,
    _nowstatus=ngx.var.status or "-",
    _request=ngx.var.request or "-",
    _bodybyte = ngx.var.body_bytes_sent or "-"  
}


if method == "GET" then
    optl.sayHtml_ext(debug_tb)
elseif method == "POST" then
    debug_tb["_PostData"] = get_postargs()
    optl.sayHtml_ext(debug_tb)
else
    ngx.say("method error")
end