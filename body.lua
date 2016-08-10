local host = ngx.req.get_headers()["Host"] or "unknownhost"
local url = ngx.unescape_uri(ngx.var.uri)
local remoteIP = ngx.var.remote_addr
local headers = ngx.req.get_headers()

local token_list = ngx.shared.token_list
local config_dict = ngx.shared.config_dict

local cjson_safe = require "cjson.safe"
local config_base = cjson_safe.decode(config_dict:get("base")) or {}


--- 2016年8月10日 增加全局Mod开关
if config_base["Mod_state"] == "off" then
	return
end

--- 判断config_dict中模块开关是否开启
local function config_is_on(config_arg)
	if config_base[config_arg] == "on" then
		return true
	end
end

if not config_is_on("replace_Mod") then return end

--- 取config_dict中的json数据
local function getDict_Config(Config_jsonName)
	local re = cjson_safe.decode(config_dict:get(Config_jsonName)) or {}
	return re
end

--- remath(str,re_str,options)
local function remath(str,re_str,options)
	if str == nil then return false end
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
		if from ~= nil or (from == 1 and to == 0 ) then
			return true
		end
	else
		local from, to = ngx.re.find(str, re_str, options)
	    if from ~= nil then
	    	return true,string.sub(str, from, to)
	    end
	end
end

--- 匹配 host 和 url
local function host_url_remath(_host,_url)
	if remath(host,_host[1],_host[2]) and remath(url,_url[1],_url[2]) then
		return true
	end
end

local function ngx_2(reps,str_all)
	for k,v in ipairs(reps) do
		local tmp3 = ngx_find(v[3])
		if v[2] == "" then
			str_all = ngx.re.sub(str_all,v[1],tmp3)
		else
			str_all = ngx.re.sub(str_all,v[1],tmp3,v[2])
		end
		
	end
	ngx.arg[1] = str_all
	token_list:delete(token_tmp)	
end

local Replace_Mod = getDict_Config("replace_Mod")


--- STEP 12
for key,value in ipairs(Replace_Mod) do  --- 从[1]开始 自上而下  仿防火墙acl机制
	if value.state =="on" then
		if host_url_remath(value.hostname,value.url) then
			if token_tmp == nil then 
				token_tmp = host..url..remoteIP..tableToString(headers)
				if token_tmp == nil then
					token_tmp = host..url..remoteIP..tableToString(headers)
				end		
			end
			if ngx.arg[1] ~= '' then -- 请求正常
				local chunk = token_list:get(token_tmp)
				if chunk == nil then
					chunk = ngx.arg[1]
					token_list:set(token_tmp,chunk,10)
				else
					chunk = chunk..ngx.arg[1]
					token_list:set(token_tmp,chunk,10)										
				end				

			end
			if ngx.arg[2] then
				ngx_2(value.replace_list,token_list:get(token_tmp))
			else
				ngx.arg[1] = nil
			end		
		end
	end
end