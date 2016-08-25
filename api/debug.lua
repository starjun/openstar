
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
local function remath(str,re_str,options)
    if str == nil or re_str == nil or options == nil then return false end
    if options == "" then
        if str == re_str or re_str == "*" then
            return true
        end
    elseif options == "table" then
        if type(re_str) ~= "table" then return false end
        for i,v in ipairs(re_str) do
            if v == str then
                return true
            end
        end
    elseif options == "in" then --- 用于包含 查找 string.find
        local from , to = string.find(str, re_str)
        --if from ~= nil or (from == 1 and to == 0 ) then
        --当re_str=""时的情况 没有处理
        if from ~= nil then
            return true
        end
    elseif options == "list" then
        if type(re_str) ~= "table" then return false end
        local re = re_str[str]
        if re == true then
            return true
        end
    elseif options == "@token@" then
        local a = tostring(token_dict:get(str))
        if a == re_str then 
            token_dict:delete(str) -- 使用一次就删除token
            return true
        end
    else
        local from, to = ngx.re.find(str, re_str, options)
        if from ~= nil then
            return true,string.sub(str, from, to)
        end
    end
end

-- 传入 (host  连接IP  http头)
local function loc_getRealIp(_host,_headers)
    if config_is_on("realIpFrom_Mod") then
        local realipfrom = getDict_Config("realIpFrom_Mod")
        local ipfromset = realipfrom[_host]
        if type(ipfromset) ~= "table" then return remoteIp end
        if remath(remoteIp,ipfromset.ips[1],ipfromset.ips[2]) then
            local ip = _headers[ipfromset.realipset]
            if ip then
                if type(ip) == "table" then ip = ip[1] end
            else
                ip = remoteIp
            end
            return ip
        else
            return remoteIp
        end
        -- 统一使用 二阶匹配
    else
        return remoteIp
    end
end

local function get_postargs()   
    ngx.req.read_body()
    local data = ngx.req.get_body_data() -- ngx.req.get_post_args()
    if not data then 
        local datafile = ngx.req.get_body_file()
        if datafile then
            local fh, err = io.open(datafile, "r")
            if fh then
                fh:seek("set")
                data = fh:read("*a")
                fh:close()
            end
        end
    end
    return ngx.unescape_uri(data)
end

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

local optl = require("optl")

if method == "GET" then
    optl.sayHtml_ext(debug_tb)
elseif method == "POST" then
    debug_tb["_PostData"] = get_postargs()
    optl.sayHtml_ext(debug_tb)
else
    ngx.say("method error")
end