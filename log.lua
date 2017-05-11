
local optl = require("optl")
local ngx_var = ngx.var
local ngx_ctx = ngx.ctx
local ngx_unescape_uri = ngx.unescape_uri

--local request_guid = ngx_ctx.request_guid
local config_dict = ngx.shared.config_dict
local config_base = optl.config_base


local  function ngx_status()
	-- 全局访问计数
	local gl_request_count = "global request count"
	optl.set_count_dict(gl_request_count)

	local gl_request_method = "global request "..(ngx_var.request_method or "unknown method")
	optl.set_count_dict(gl_request_method)

	-- host - uri 计数
	local host = ngx_var.http_host or "unknown host"
	local server_name = ngx_var.server_name

	if server_name == "localhost" or server_name == "localhost:5460" then
		host = server_name
	end

	local host_uri = ngx_var.scheme.."://"..host..ngx_unescape_uri(ngx_var.uri)
	optl.set_count_dict(host_uri)
end

if config_base.ngx_status == "on" then
	ngx_status()
end