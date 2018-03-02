
---- 调试使用原样将数据包格式化后返回
local ngx_var = ngx.var
local ngx_unescape_uri = ngx.unescape_uri

local headers = ngx.req.get_headers()
local args = ngx.req.get_uri_args()
local lua_version

--- ngx.var 虚表
local ngxVar = {}

ngxVar.status=ngx_var.status
ngxVar.scheme = ngx_var.scheme
ngxVar.request_method = ngx_var.request_method
ngxVar.uri = ngx_unescape_uri(ngx_var.uri)
ngxVar.request_uri = ngx_unescape_uri(ngx_var.request_uri)
ngxVar.document_uri = ngx_var.document_uri
ngxVar.request=ngx_var.request

ngxVar.server_addr = ngx_var.server_addr
ngxVar.server_port = ngx_var.server_port
ngxVar.server_protocol = ngx_var.server_protocol

ngxVar.remote_addr = ngx_var.remote_addr
ngxVar.host = ngx_var.host
ngxVar.http_host = ngx_var.http_host
ngxVar.hostname = ngx_var.hostname
ngxVar.server_name = ngx_var.server_name
ngxVar.sent_http_host = ngx_var.sent_http_host

ngxVar.document_root = ngx_var.document_root
ngxVar.realpath_root = ngx_var.realpath_root
ngxVar.request_filename = ngx_var.request_filename
ngxVar.query_string = ngx_unescape_uri(ngx_var.query_string)


ngxVar.remote_port = ngx_var.remote_port
ngxVar.remote_user = ngx_var.remote_user
ngxVar.remote_passwd = ngx_var.remote_passwd
ngxVar.http_content_type = ngx_var.http_content_type
ngxVar.content_length = ngx_var.content_length
ngxVar.body_bytes_sent = ngx_var.body_bytes_sent
ngxVar.bytes_sent = ngx_var.bytes_sent

ngxVar.connection = ngx_var.connection
ngxVar.connection_requests = ngx_var.connection_requests


ngxVar.limit_rate = ngx_var.limit_rate
ngxVar.msec = ngx_var.msec
ngxVar.nginx_version = ngx_var.nginx_version

ngxVar.pid = ngx_var.pid
ngxVar.pipe = ngx_var.pipe
ngxVar.proxy_protocol_addr = ngx_var.proxy_protocol_addr
ngxVar.proxy_protocol_port = ngx_var.proxy_protocol_port

ngxVar.request_completion = ngx_var.request_completion
ngxVar.request_id = ngx_var.request_id
ngxVar.request_length = ngx_var.request_length

ngxVar.time_local=ngx_var.time_local
ngxVar.request_time = ngx_var.request_time
ngxVar.time_iso8601 = ngx_var.time_iso8601
ngxVar.time_local = ngx_var.time_local

-- local cjson_safe = require "cjson.safe"
local optl = require("optl")
local ini = require "resty.ini"

local config_base = optl.config.base or {}

if jit then
    lua_version = jit.version
else
    lua_version = _VERSION
end
local dist = ini.parse_file(config_base.baseDir.."dist.ini")
local debug_tb = {
    _Openstar_version = dist.default,
    _pid = ngx.worker.pid(),
    _worker_count =ngx.worker.count(),
    _worker_id = ngx.worker.id(),
    _ngx_configure=ngx.config.nginx_configure(),
    _ngx_prefix=ngx.config.prefix(),
    _lua_version = lua_version,
    _ngx_lua_version = ngx.config.ngx_lua_version,
    _ngx_version = ngx.config.nginx_version,

    _args = args,
    _headers = headers,

    _ngxVar = ngxVar

}


if ngxVar.request_method == "GET" then
    optl.sayHtml_ext(debug_tb)
elseif ngxVar.request_method == "POST" then
    local post_all = optl.get_post_all()
    local parser = require "bodyparser"
    local p, err = parser.new(post_all, ngx_var.http_content_type,100)
    if not p then
        debug_tb["_PostData_error"] = post_all
        debug_tb["get_post_args"] = ngx.req.get_post_args()
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