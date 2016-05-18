
-----  自定义lua脚本 by zj -----
local remoteIp = ngx.var.remote_addr
local headers = ngx.req.get_headers()
local host = ngx.req.get_headers()["Host"] or "unknownhost"
local method = ngx.var.request_method
local url = ngx.unescape_uri(ngx.var.uri)
local referer = headers["referer"] or "unknownreferer"
local agent = headers["user_agent"] or "unknownagent"	
local request_url = ngx.unescape_uri(ngx.var.request_uri)


local config_dict = ngx.shared.config_dict

--- config_is_on()
local function config_is_on(config_arg)	
	if config_dict:get(config_arg) == "on" then
		return true
	end
end

-- 传入 (host  连接IP  http头)
local function loc_getRealIp(host,remoteIP,headers)
	if config_is_on("realIpFrom_Mod") then
		local realipfrom = realIpFrom_Mod or {}
		local ipfromset = realipfrom[host]		
		if type(ipfromset) ~= "table" then return remoteIP end
		if ipfromset.ips == "" then
			local ip = headers[ipfromset.realipset]
			if ip then
				if type(ip) == "table" then ip = ip[1] end  --- http头中又多个取第一个
			else
				ip = remoteIP
			end
			return ip
		else
			for i,v in ipairs(ipfromset.ips) do
				if v == remoteIP then
					local ip = headers[ipfromset.realipset]
					if ip then
						if type(ip) == "table" then ip = ip[1] end  --- http头中又多个取第一个
					else
						ip = remoteIP
					end
					return ip
				end
			end
			return remoteIP
		end
	end
end
local ip = loc_getRealIp(host,remoteIp,headers)


--- remath(str,re_str,options)
local function remath(str,re_str,options)
	if str == nil then return false end
	if options == "" then
		if str == re_str or re_str == "*" then
			return true
		end
	elseif options == "table" then
		for i,v in ipairs(re_str) do
			if v == str then
				return true
			end
		end
	else
		local from, to = ngx.re.find(str, re_str, options)
	    if from ~= nil then
	    	return true
	    end
	end
end

--- 匹配 host 和 url
local function host_url_remath(_host,_url)
	if remath(host,_host[1],_host[2]) and remath(url,_url[1],_url[2]) then
		return true
	end
end

--- 
local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end

local tb_do = {
				host={"*",""},
				url={[[/dodo]],""}
			}


if host_url_remath(tb_do.host,tb_do.url) then
	ngx.say("ABC.ABC IS ABC")
	return "break"   --- break 表示跳出for循环
else
	return  ---- 否则继续for循环 继续规则判断
end


