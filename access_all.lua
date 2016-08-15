-----  access_all by zj  -----
local remoteIp = ngx.var.remote_addr
local headers = ngx.req.get_headers()
local host = headers["Host"] or "unknown-host"
local method = ngx.var.request_method
local url = ngx.unescape_uri(ngx.var.uri)
local referer = headers["referer"] or "unknown-referer"
local agent = headers["user_agent"] or "unknown-agent"	
--local request_url = ngx.unescape_uri(ngx.var.request_uri)

local config_dict = ngx.shared.config_dict
local limit_ip_dict = ngx.shared.limit_ip_dict
local ip_dict = ngx.shared.ip_dict
local count_dict = ngx.shared.count_dict
local token_list = ngx.shared.token_list

local cjson_safe = require "cjson.safe"
local config_base = cjson_safe.decode(config_dict:get("base")) or {}

--- 2016年8月4日 增加全局Mod开关
if config_base["Mod_state"] == "off" then
	return
end

--- 判断config_dict中模块开关是否开启
local function config_is_on(config_arg)
	if config_base[config_arg] == "on" then
		return true
	end
end

--- 取config_dict中的json数据
local function getDict_Config(Config_jsonName)
	local re = cjson_safe.decode(config_dict:get(Config_jsonName)) or {}
	return re
end

-- 传入 (host  连接IP  http头)
local function loc_getRealIp(host,remoteIP,headers)
	if config_is_on("realIpFrom_Mod") then
		local realipfrom = getDict_Config("realIpFrom_Mod")
		local ipfromset = realipfrom[host]
		if ipfromset == nil or type(ipfromset) ~= "table" then return remoteIP end
		-- if remath(remoteIP,ipfromset.ips[1],ipfromset.ips[2]) then
		-- 	local ip = headers[ipfromset.realipset]
		-- 	if ip then
		-- 		if type(ip) == "table" then ip = ip[1] end
		-- 	else
		-- 		ip = remoteIP
		-- 	end
		-- 	return ip
		-- else
		-- 	return remoteIP
		-- end
		-- 统一使用 二阶匹配
		if ipfromset.ips == "*" then
			local ip = headers[ipfromset.realipset]
			if ip then
				if type(ip) == "table" then ip = ip[1] end  --- http头中有多个取第一个
			else
				ip = remoteIP
			end
			return ip
		else
			if type(ipfromset.ips) ~= "table" then return remoteIP end
			for i,v in ipairs(ipfromset.ips) do
				if v == remoteIP then
					local ip = headers[ipfromset.realipset]
					if ip then
						if type(ip) == "table" then ip = ip[1] end
					else
						ip = remoteIP
					end
					return ip
				end
			end
			return remoteIP
		end
	else
		return remoteIP
	end
end

--- remath(str,re_str,options)
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
		--当re_str=""时的情况
		if from ~= nil then
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

--- 获取单个args值
local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end

--- 拦截计数 2016年6月7日 21:52:52 up 从全局变成local
local function Set_count_dict(_key)
	if _key == nil then return end
	local key_count = count_dict:get(_key)
	if key_count == nil then 
		count_dict:set(_key,1)
	else
		count_dict:incr(_key,1)
	end
end

-- action_deny(code) 拒绝访问
-- 2016年6月7日 21:55:13 up 从全局调整为 local
local function action_deny(code)
	if code == nil or type(code) ~= "number" then
		ngx.header["Content-Type"] = "text/plain"
		--local default = [[<!DOCTYPE html><html><head><title>Error</title><style>body {width: 35em;margin: 0 auto;font-family: Tahoma, Verdana, Arial, sans-serif;}</style></head><body><h1>An error occurred.</h1><p>Sorry, the page you are looking for is currently unavailable.<br/>Please try again later.</p><p>If you are the system administrator of this resource then you should checkthe <a href="http://nginx.org/r/error_log">error log</a> for details.</p><p><em>Faithfully yours, nginx.</em></p></body></html>]]
		local msg = config_base.sayHtml or "OpenStar request error"
		ngx.say(msg) 
		return ngx.exit(200)
	else
		return ngx.exit(code)
	end
end

local function get_postargs()	
	ngx.req.read_body()
	local data = ngx.req.get_body_data() -- ngx.req.get_post_args()
	if not data then 
		local datafile = ngx.req.get_body_file()
		if datafile then
			local fh, err = io.open(datafile, "r")
			if fh then
				fh:seek("set")
                data = fh:read("*a")
                fh:close()
			end
		end
	end
	return ngx.unescape_uri(data)
end

local post_date
local get_date

--- STEP 0
local ip = loc_getRealIp(host,remoteIp,headers)
--debug("----------- STEP 0  "..ip)


---  STEP 1 
-- black/white ip 访问控制(黑/白名单/log记录)
-- 2016年7月29日19:12:53 检查
if config_is_on("ip_Mod") then
	local _ip_v = ip_dict:get(ip) --- 全局IP 黑白名单
	if _ip_v ~= nil then
		if _ip_v == "allow" then -- 跳出后续规则
			return
		elseif _ip_v == "log" then 
			Set_count_dict("ip log count")
	 		debug("ip_Mod : log","ip_log",ip)
		else
			Set_count_dict(ip)
			action_deny()
		end
	end
	local host_ip = ip_dict:get(host.."-"..ip)
	if host_ip ~= nil then
		if host_ip == "allow" then -- 跳出后续规则
			return
		elseif host_ip == "log" then 
			Set_count_dict(host.."-ip log count")
	 		debug(host.."-ip_Mod : log","ip_log",ip)
		else
			Set_count_dict(host.."-"..ip)
			action_deny()
		end
	end
end
--debug("----------- STEP 1")

---  STEP 2
-- host and method  访问控制(白名单)
-- 2016年7月29日19:14:31  检查
if host == "unknown-host" then 
	Set_count_dict("black_host_method count")
	debug("host_method_Mod : black","host_method_deny",ip)
	action_deny()
end

if config_is_on("host_method_Mod") then
	local tb_mod = getDict_Config("host_method_Mod")
	local check
	for i,v in ipairs(tb_mod) do
		if v.state == "on" then
			if remath(host,v.hostname[1],v.hostname[2]) and remath(method,v.method[1],v.method[2]) then
				check = "allow"
				break
			end
		end
	end
	if check ~= "allow" then
		Set_count_dict("black_host_method count")
	 	debug("host_method_Mod : black","host_method_deny",ip)
	 	action_deny()
	end
end
--debug("----------- STEP 2")

--- STEP 2.1
-- rewrite 跳转阶段(set-cookie)
-- 本来想着放到rewrite阶段使用的，方便统一都放到access阶段了。
if config_is_on("rewrite_Mod") then
	local tb_mod = getDict_Config("rewrite_Mod")
	for i,v in ipairs(tb_mod) do
		if v.state == "on" then
			if host_url_remath(v.hostname,v.url) then
				if v.action[1] == "set-cookie" then
					local token = ngx.md5(v.action[2] .. ip)
		            if (ngx.var.cookie_token ~= token) then
		                ngx.header["Set-Cookie"] = {"token=" .. token}
		                if method == "POST" then
		                	return ngx.redirect(ngx.var.request_uri,307)
		                else
		                	return ngx.redirect(ngx.var.request_uri)
		                end
		            end
				else
				
				end
				break
			end
		end
	end
end

-- --- STEP 3
-- -- app_Mod 访问控制 （自定义action）
-- -- 目前支持的 deny allow log rehtml refile relua
if config_is_on("app_Mod") then
	local app_mod = getDict_Config("app_Mod")
	for i,v in ipairs(app_mod) do
		if v.state == "on" then
			--debug("app_Mod state is on "..i)
			if host_url_remath(v.hostname,v.url) then
				
				if v.action[1] == "deny" then
					Set_count_dict("app_deny count")
					debug("app_Mod deny No : "..i,"app_log",ip)
					action_deny()
					break

				elseif v.action[1] == "allow" then
					--debug("app_Mod action = allow")
					local check
					if v.allow[1] == "args" then
						local get_args = get_argByName(v.allow[2])
						--debug("get_args by keyby : "..get_args.."")
						if v.allow[3] == "@token@" then --- 服务端验证							
							local a = token_list:get(get_args)
							if a == true then 
								token_list:delete(get_args) -- 使用一次就删除token
								check = "allow"	
							end
						else
						    if remath(get_args,v.allow[3],"jio") then
								check = "allow"
							end
						end						
					elseif v.allow[1] == "ip" then -- 增加IP判断（eg:对某url[文件夹进行IP控制]）
						if remath(ip,v.allow[2],v.allow[3]) then
							check = "allow"
						end
					end

					if check == "allow" then
						--return
					else
						Set_count_dict("app_deny count")
						debug("app_Mod allow : "..v.allow[1].." No : "..i,"app_log",ip)
						action_deny()
						break
					end					

				elseif v.action[1] == "log" then
					local http_tmp = {}
					http_tmp["headers"] = headers
					get_date = ngx.unescape_uri(ngx.var.query_string)
					http_tmp["get_date"] = get_date
					http_tmp["remoteIp"] = remoteIp
					if method == "POST" then
						post_date = get_postargs()
						http_tmp["post"] = post_date						
					end
					debug("app_Mod log Msg : "..tableTojson(http_tmp),"app_log",ip)

				elseif v.action[1] == "rehtml" then
					sayHtml_ext(v.rehtml)
					break

				elseif v.action[1] == "reflie" then
					sayFile(v.reflie)
					break

				elseif v.action[1] == "relua" then
					local re_saylua = sayLua(v.relua)
					if re_saylua == "break" then
						ngx.exit(200)
						break
					end

				elseif v.action[1] == "set" then -- 预留
					break
				else
					break
				end 
			end
		end
	end
end
--debug("----------- STEP 3")

-- --- STEP 4
-- -- referer (白名单/log记录/next)
if config_is_on("referer_Mod") then
	local check,no
	local ref_mod = getDict_Config("referer_Mod")
	for i, v in ipairs( ref_mod ) do
		if v.state == "on" then
			no = i
			if host_url_remath(v.hostname,v.url) then
				if v.action == "allow" then
					if remath(referer,v.referer[1],v.referer[2]) then
						check = "allow"
						break					
					else
						check = "deny"
						break
					end
				elseif v.action == "next" then
					if remath(referer,v.referer[1],v.referer[2]) then
						check = "next"
						break
					else
						check = "deny"
						break
					end
				elseif v.action == "log" then
					if remath(referer,v.referer[1],v.referer[2]) then
						check = "log"
						break
					end
				else
					if remath(referer,v.referer[1],v.referer[2]) then
						check = "deny"
						break
					end
				end
			end
		end
	end
	if check == "allow" then --- 直接跳出后续规则检查
		return
	elseif check == "next" then
		-- nil
	elseif check == "log" then
		Set_count_dict("referer_deny count")
		debug("referer_Mod "..referer.." No : "..no,"referer_log",ip)
	elseif check == "deny" then
		Set_count_dict("referer_deny count")
		debug("referer_Mod "..referer.." No : "..no,"referer_deny",ip)
		action_deny()
	else
		
	end
end
--debug("----------- STEP 4")

--- STEP 5
-- url 过滤(黑/白名单)
if config_is_on("url_Mod") then
	local url_mod = getDict_Config("url_Mod")
	local t,no
	for i, v in ipairs( url_mod ) do
		no = i
		if v.state == "on" then
			if host_url_remath(v.hostname,v.url) then
				t = v.action
				break
			end
		end
	end
	if t == "allow" then --- 跳出后续规则
		return
	elseif t ==	"deny" then
		Set_count_dict("url_deny count")
		debug("url_Mod No : "..no,"url_deny",ip)
		action_deny()
	elseif t == "log" then
		Set_count_dict("url_log count")
		debug("url_Mod No : "..no,"url_log",ip)
	end
end
--debug("----------- STEP 5")

--- STEP 6
-- header 过滤(黑名单) [scanner]
if config_is_on("header_Mod") then
	local tb_mod = getDict_Config("header_Mod")
	for i,v in ipairs(tb_mod) do
		if v.state == "on" then			
			if host_url_remath(v.hostname,v.url) then
				if remath(headers[v.header[1]],v.header[2],v.header[3]) then
					Set_count_dict("black_header_method count")
				 	debug("header_Mod No : "..i,"header_deny",ip)
				 	action_deny()
				 	break
				end
			end
		end
	end
end

--debug("----------- STEP 6")

--- STEP 7
-- useragent(黑、白名单/log记录)
if config_is_on("agent_Mod") then	
	local uagent_mod = getDict_Config("useragent_Mod")
	for i, v in ipairs( uagent_mod ) do
		if v.state == "on" then
			--debug(i.." agent_Mod state is on")
			if remath(host,v.hostname[1],v.hostname[2]) then
				--debug("useragent host is ok")
				if remath(agent,v.useragent[1],v.useragent[2]) then
					if v.action == "allow" then
						return
					elseif v.action == "log" then
						Set_count_dict("agent_deny count")
						debug("agent_Mod : "..agent.." No : "..i,"agent_log",ip)
						break
					else
						Set_count_dict("agent_deny count")
						debug("agent_Mod : "..agent.." No : "..i,"agent_deny",ip)
						action_deny()
						break
					end
				end
			end
		end
	end
end

--debug("----------- STEP 7")

--- STEP 8
-- cookie (黑/白名单/log记录)
local cookie = headers["cookie"]

if config_is_on("cookie_Mod") and cookie ~= nil then
	cookie = ngx.unescape_uri(cookie)
	local cookie_mod = getDict_Config("cookie_Mod")
	for i, v in ipairs( cookie_mod ) do
		if v.state == "on" then
			if remath(host,v.hostname[1],v.hostname[2]) then
				if remath(cookie,v.cookie[1],v.cookie[2]) then
					if v.action == "deny" then
						Set_count_dict("cookie_deny count")
						debug("cookie_Mod : "..cookie.." No : "..i,"cookie_deny",ip)
						action_deny()
						break
					elseif v.action =="log" then
						Set_count_dict("cookie_log count")
						debug("cookie_Mod : "..cookie.." No : "..i,"cookie_log",ip)
						break
					elseif v.action == "allow" then
						return
					end
				end
			end
		end
	end
end

--debug("----------- STEP 8")

--- STEP 9
-- args (黑/白名单/log记录)
if config_is_on("args_Mod") then
	--debug("args_Mod is on")
	local args_mod = getDict_Config("args_Mod")
	local args = get_date or ngx.unescape_uri(ngx.var.query_string)
	if args ~= "" then
		for i,v in ipairs(args_mod) do
			if v.state == "on" then
				--debug("args_Mod state is on "..i)
				if remath(host,v.hostname[1],v.hostname[2]) then			
					if remath(args,v.args[1],v.args[2]) then
						if v.action == "deny" then
							Set_count_dict("args_deny count")
							debug("args_Mod _args = "..args.." No : "..i,"args_deny",ip)
							action_deny()
							break
						elseif v.action == "log" then
							Set_count_dict("args_log count")
							debug("args_Mod _args = "..args.." No : "..i,"args_log",ip)
							break
						elseif v.action == "allow" then
							return							
						end
					end
				end
			end
		end
	end
end
--debug("----------- STEP 9")

--- STEP 10
-- post (黑/白名单)

if config_is_on("post_Mod") and method == "POST" then
	--debug("post_Mod is on")
	local post_mod = getDict_Config("post_Mod")
	local postargs = post_date or get_postargs()
	if postargs ~= "" then
		for i,v in ipairs(post_mod) do
			if v.state == "on" then
				--debug(i.." post_mod state is on")
				if remath(host,v.hostname[1],v.hostname[2]) then
					if remath(postargs,v.post[1],v.post[2]) then
						if v.action == "deny" then
							Set_count_dict("post_deny count")
							debug("post_Mod : "..postargs.."No : "..i,"post_deny",ip)
							action_deny()
							break
						elseif v.action == "log" then
							Set_count_dict("post_log count")
							debug("post_Mod : "..postargs.."No : "..i,"post_log",ip)
							break
						elseif v.action == "allow" then
							return
						end
					end
				end
			end
		end
	end
end

--debug("----------- STEP 10")

--- STEP 11
-- network_Mod 访问控制
if config_is_on("network_Mod") then
	local tb_networkMod = getDict_Config("network_Mod")
	for i, v in ipairs( tb_networkMod ) do
		if v.state =="on" then
			if host_url_remath(v.hostname,v.url) then
				local mod_ip = ip.." network_Mod No "..i
				local ip_count = limit_ip_dict:get(mod_ip)
				if ip_count == nil then
					local pTime =  v.network.pTime or 10
					limit_ip_dict:set(mod_ip,1,pTime)
				else
					local maxReqs = v.network.maxReqs or 50
					if ip_count >= maxReqs then
						--debug("maxReqs is true")
						local blacktime = v.network.blackTime or 10*60
						ip_dict:safe_set(ip,mod_ip,blacktime)
						debug("network_Mod  check_network No : "..i,"network_log",ip)
						action_deny()
						break
					else
					    limit_ip_dict:incr(mod_ip,1)
					end
				end
			end
		end
	end
end

--debug("----------- STEP 11")