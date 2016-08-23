
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
	else
		return remoteIp
	end
end
local ip = loc_getRealIp(host,headers)




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
				url={[[/api/time]],""}
			}


if host_url_remath(tb_do.host,tb_do.url) then
	ngx.say("ABC.ABC IS ABC")
	return "break"   --- break 表示跳出for循环
else
	return  ---- 否则继续for循环 继续规则判断
end


