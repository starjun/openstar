
local optl = require("optl")
local ngx_var = ngx.var
local next_ctx = ngx.ctx.next_ctx or {}
local ngx_unescape_uri = ngx.unescape_uri
local base_msg = next_ctx.base_msg
local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local table_insert = table.insert
local table_concat = table.concat
local io_open = io.open

if type(base_msg) == "table" then
    -- 时间
    base_msg.time = ngx.localtime()
    -- 协议版本 “HTTP/1.0”, “HTTP/1.1”, or “HTTP/2.0”
    base_msg.server_protocol = ngx_var.server_protocol
    -- 状态
    base_msg.status = ngx_var.status
    -- 返回长度
    base_msg.body_bytes_sent = ngx_var.body_bytes_sent or 0
end

local config_base = optl.config.base or {}
local fd = G_filehandler

local  function ngx_status()
    -- 全局访问计数
    local gl_request_count = "global request count"
    optl.set_count_dict(gl_request_count)

    local gl_request_method = "global request "..(ngx_var.request_method or "unknown method")
    optl.set_count_dict(gl_request_method)

    -- host - uri 计数
    local host = ngx_var.http_host or "unknown host"
    local server_name = ngx_var.server_name

    if server_name == "localhost" or server_name == "localhost5460" then
        host = server_name
    end

    local host_uri = ngx_var.scheme.."://"..host..ngx_unescape_uri(ngx_var.uri)
    optl.set_count_dict(host_uri)
end

if config_base.ngx_status == "on" then
    ngx_status()
end

local function logformat(_basemsg,_log_conf)
    local log_map = {}
    for k,v in pairs(_basemsg) do
        log_map["$"..k] = v
    end
    local re_log_tb = {}
    for _,v in ipairs(_log_conf.tb_formart) do
        local x = log_map[v] or v
        if type(x) == "table" then
            x = optl.tableTojson(x)
        end
        table_insert(re_log_tb,x)
    end
    return table_concat(re_log_tb,_log_conf.tb_concat)
end

local function writefile_handler(_filepath,_msg,_ty)
    _ty = _ty or "a+"
    if not fd then
        fd = io_open(_filepath,_ty)
        if not fd then
            ngx.log(ngx.ERR,"writefile msg : "..tostring(_msg))
            return
        else
            G_filehandler = fd
        end
    end
    fd:write(tostring(_msg))
    fd:flush()
end

if next_ctx.waf_log and config_base.log_conf.state == "on" then
    base_msg.waf_log = next_ctx.waf_log
    local log_str = logformat(base_msg,config_base.log_conf)
    writefile_handler(config_base.logPath..(config_base.log_conf.filename or "waf.log"),log_str)
end