local host = ngx.req.get_headers()["Host"] or "unknownhost"
local url = ngx.unescape_uri(ngx.var.uri)
local remoteIP = ngx.var.remote_addr
local headers = ngx.req.get_headers()
local token_list = ngx.shared.token_list

--- config_is_on()
local function config_is_on(config_arg)
	local config_dict = ngx.shared.config_dict
	if config_dict:get(config_arg) == "on" then
		return true
	end
end


if config_is_on("replace_Mod") ==  false then return end

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

local Replace_Mod = replace_Mod


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