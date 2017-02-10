
local optl = require("optl")
local ngx_var = ngx.var
local ngx_unescape_uri = ngx.unescape_uri

local request_guid = ngx.ctx.request_guid
optl.del_token(request_guid)

-- 全局访问计数
local gl_request_count = "global request count"
optl.set_count_dict(gl_request_count)

local gl_request_method = "global request "..ngx_var.request_method
optl.set_count_dict(gl_request_method)

-- host - uri 计数
local host = ngx_var.http_host

-- if ngx_var.server_name == "localhost" or ngx_var.server_name == "localhost:5460" then
-- 	host = ngx_var.server_name
-- end

local host_uri = ngx_var.scheme.."://"..host..ngx_unescape_uri(ngx_var.uri)
optl.set_count_dict(host_uri)