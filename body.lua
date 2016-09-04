
local url = ngx.unescape_uri(ngx.var.uri)
local remoteIP = ngx.var.remote_addr
local headers = ngx.req.get_headers()
local host = ngx.unescape_uri(ngx.var.http_host)

local token_dict = ngx.shared.token_dict
local config_dict = ngx.shared.config_dict

local cjson_safe = require "cjson.safe"
local config_base = cjson_safe.decode(config_dict:get("base")) or {}


local optl = require("optl")

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
--- 常用二阶匹配规则
local remath = optl.remath

--- 匹配 host 和 url
local function host_url_remath(_host,_url)
	if remath(host,_host[1],_host[2]) and remath(url,_url[1],_url[2]) then
		return true
	end
end

local function ngx_2(reps,str_all)
	for k,v in ipairs(reps) do
		local tmp3 = optl.ngx_find(v[3])
		if v[2] == "" then
			str_all = ngx.re.sub(str_all,v[1],tmp3)
		else
			str_all = ngx.re.sub(str_all,v[1],tmp3,v[2])
		end
		
	end
	ngx.arg[1] = str_all
	token_dict:delete(token_tmp)	
end

local Replace_Mod = getDict_Config("replace_Mod")


--- STEP 12
for key,value in ipairs(Replace_Mod) do  --- 从[1]开始 自上而下  仿防火墙acl机制
	if value.state =="on" then
		if host_url_remath(value.hostname,value.url) then
			if token_tmp == nil then 
				token_tmp = host..url..remoteIP..optl.tableTostring(headers)
				---  检查（可以删除）
				if token_tmp == nil then
					token_tmp = host..url..remoteIP..optl.tableTostring(headers)
				end
				---
			end
			if ngx.arg[1] ~= '' then -- 请求正常
				local chunk = token_dict:get(token_tmp)
				if chunk == nil then
					chunk = ngx.arg[1]
					token_dict:set(token_tmp,chunk,10)
				else
					chunk = chunk..ngx.arg[1]
					token_dict:set(token_tmp,chunk,10)										
				end				

			end
			if ngx.arg[2] then
				ngx_2(value.replace_list,token_dict:get(token_tmp))
			else
				ngx.arg[1] = nil
			end		
		end
	end
end