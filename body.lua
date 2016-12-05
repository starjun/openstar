
--if ngx.req.is_internal() then return end

local ngx_unescape_uri = ngx.unescape_uri
local ngx_var = ngx.var


local remoteIP = ngx_var.remote_addr
local uri = ngx_unescape_uri(ngx_var.uri)
local host = ngx_unescape_uri(ngx_var.http_host)
local headers = ngx.req.get_headers()

local token_dict = ngx.shared.token_dict
local config_dict = ngx.shared.config_dict
local host_dict = ngx.shared.host_dict

local cjson_safe = require "cjson.safe"
local config_base = cjson_safe.decode(config_dict:get("base")) or {}
local host_Mod_state = host_dict:get(host)

local optl = require("optl")

--- 2016年8月10日 增加全局Mod开关
if config_base["Mod_state"] == "off" or host_Mod_state == "off" then
	return
end

--- 判断config_dict中模块开关是否开启
local config_is_on = optl.config_is_on

if not config_is_on("replace_Mod") then return end

--- 取config_dict中的json数据
local getDict_Config = optl.getDict_Config

--- remath(str,re_str,options)
--- 常用二阶匹配规则
local remath = optl.remath

--- 匹配 host 和 uri
local function host_uri_remath(_host,_uri)
	if _host == nil or _uri == nil then
		return false
	end
	if remath(host,_host[1],_host[2]) and remath(uri,_uri[1],_uri[2]) then
		return true
	end
end

-- 返回内容的替换使用 ngx.re.sub 后续会更新用户可指定替换函数(如 ngx.re.gsub)
-- 参考使用资料 http://blog.csdn.net/weiyuefei/article/details/38439017
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

-- ngx.ctx.request_guid 一定要保证存在
local token_tmp = tostring(ngx.ctx.request_guid)..remoteIP

--- STEP 12
for key,value in ipairs(Replace_Mod) do
	--- 从[1]开始 自上而下  仿防火墙acl机制
	if value.state =="on" and host_uri_remath(value.hostname,value.uri) then

		if ngx.arg[1] ~= '' then -- 请求正常
			local chunk = token_dict:get(token_tmp)
			if chunk == nil then
				chunk = ngx.arg[1]
				token_dict:set(token_tmp,chunk,15)
			else
				chunk = chunk..ngx.arg[1]
				token_dict:set(token_tmp,chunk,15)
			end				

		end
		if ngx.arg[2] then
			ngx_2(value.replace_list,token_dict:get(token_tmp))
		else
			ngx.arg[1] = nil
		end		

	end
end