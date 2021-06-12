
-----  自定义lua脚本 by zj -----
local optl = require "optl"
local headers = ngx.req.get_headers()
local host = ngx.unescape_uri(headers["Host"])
local url = ngx.unescape_uri(ngx.var.uri)


local token_dict = ngx.shared.token_dict


--- 匹配 host 和 url
local function host_url_remath(_host,_url)
	if optl.remath(host,_host[1],_host[2]) and optl.remath(url,_url[1],_url[2]) then
		return true
	end
end


local tb_do = {
				host={"*",""},
				url={[[/api/debug]],""}
			}


if host_url_remath(tb_do.host,tb_do.url) then
	ngx.say("ABC.ABC IS ABC")
	return "break"   --- break 表示跳出for循环
else
	return  ---- 否则继续for循环 继续规则判断
end


