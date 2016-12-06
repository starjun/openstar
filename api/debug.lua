
---- 调试使用原样将数据包格式化后返回


local headers = ngx.req.get_headers()
local host = ngx.unescape_uri(headers["Host"])
local method = ngx.var.request_method
local args = ngx.req.get_uri_args()
local uri = ngx.unescape_uri(ngx.var.uri)
local request_uri = ngx.unescape_uri(ngx.var.request_uri)
local remoteIp = ngx.var.remote_addr
local lua_version


local config_dict = ngx.shared.config_dict

local cjson_safe = require "cjson.safe"
local config_base = cjson_safe.decode(config_dict:get("base")) or {}

local optl = require("optl")

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
    _uri = uri,
    _method = method,
    _request_uri = request_uri,
    _args = args,
    _headers = headers,
    _schema = ngx.var.schema,
    _var_host = ngx.var.host,
    _hostname = ngx.var.hostname,
    _servername = ngx.var.server_name or "unknownserver",
    _remoteIp = remoteIp,
    _ip = optl.loc_getRealIp(host,remoteIp),
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
    local post_str = get_postargs()
    local parser = require "bodyparser"
    local p, err = parser.new(post_str, ngx.var.http_content_type)
    if not p then
        debug_tb["_PostData_error"] = post_str
        optl.sayHtml_ext(debug_tb)
    end

    local tmp_tb = {}
    while true do
       local part_body, name, mime, filename = p:parse_part()
       if not part_body then
          break
       end
       table.insert(tmp_tb, {name,filename,mime,part_body})
    end
    debug_tb["_PostData"] = tmp_tb
    optl.sayHtml_ext(debug_tb)
else
    optl.sayHtml_ext({code="error",msg="method error"})
end