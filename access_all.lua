-----  access_all by zj  -----
local remoteIp = ngx.var.remote_addr
local headers = ngx.req.get_headers()
local host = ngx.req.get_headers()["Host"] or "unknownhost"
local method = ngx.var.request_method
local url = ngx.unescape_uri(ngx.var.uri)
local referer = headers["referer"] or "unknownreferer"
local agent = headers["user_agent"] or "unknownagent"	
local request_url = ngx.unescape_uri(ngx.var.request_uri)

local config_dict = ngx.shared.config_dict
local limit_ip_dict = ngx.shared["limit_ip_dict"]
local ip_dict = ngx.shared["ip_dict"]

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

--- 获取单个args值
local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end

--- STEP 0
local ip = loc_getRealIp(host,remoteIp,headers)
--debug("----------- STEP 0  "..ip)

---  STEP 1 
-- black/white ip 访问控制(黑/白名单)
if config_is_on("ip_Mod") then	
	local _ip_v = ip_dict:get(ip)
	if _ip_v ~= nil then
		if _ip_v == "allow" then
			return
		else
			Set_count_dict(ip)
			action_deny()
		end
	end
end
--debug("----------- STEP 1")

---  STEP 2
-- host and method  访问控制(白名单)
if config_is_on("host_method_Mod") then
	local tb_mod = host_method_Mod or {}
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
		Set_count_dict(" black_host_method count")
	 	debug("<host error> ip "..ip,"host_method_deny")
	 	action_deny()
	end
end
--debug("----------- STEP 2")

--- STEP 3
-- app_Mod 访问控制
if config_is_on("app_Mod") then
	local app_mod = app_Mod or {}
	for i,v in ipairs(app_mod) do
		if v.state == "on" then
			--debug("app_Mod state is on "..i)
			if host_url_remath(v.hostname,v.url) then				
				if v.action[1] == "deny" then
					Set_count_dict("app_deny count")
					debug("app_Mod deny","app_log")
					action_deny()
					break
				elseif v.action[1] == "allow" then
					--debug("app_Mod action = allow")
					local check
					if v.allow[1] == "args" then
						local get_args = get_argByName(v.allow[2])
						--debug("get_args by keyby : "..get_args)
						if v.allow[3] == "@token@" then --- 服务器验证
							local token_list = ngx.shared.token_list;
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
						--debug("v.allow == ip")
						if remath(ip,v.allow[2],v.allow[3]) then
							check = "allow"
						end
					end
					if check == "allow" then
						--return
					else
						Set_count_dict("app_deny count")
						debug("app_Mod allow[false]"..v.allow[1],"app_log")
						action_deny()
						break
					end					
				elseif v.action[1] == "log" then
					debug("app_Mod log","app_log")
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
				elseif v.action[1] == "set" then

				else
					break
				end 
			end
		end
	end
end
--debug("----------- STEP 3")

--- STEP 4
-- referer (白名单)
local function check_referer(_referer)
	local ref_mod = referer_Mod or {}
	for i, v in ipairs( ref_mod ) do
		if v.state == "on" then
			if host_url_remath(v.hostname,v.url) then
				if remath(_referer,v.referer[1],v.referer[2]) then
					return true
				else
					return false
				end
			end
		end
	end
end
if config_is_on("referer_Mod") then
	local check = check_referer(referer)
	if check == true then
		return
	elseif check == false then
		Set_count_dict("referer_deny count")
		debug("referer "..referer.." ip "..ip,"referer_deny")
		action_deny()
	else

	end
end
--debug("----------- STEP 4")

--- STEP 5
-- url 过滤(黑白名单)
local function check_url()
	local url_mod = url_Mod or {}	
	for i, v in ipairs( url_mod ) do
		if v.state == "on" then
			if host_url_remath(v.hostname,v.url) then
				return v.action
			end
		end
	end
end
if config_is_on("url_Mod") then
	local t = check_url()
	if t == "allow" then
		return
	elseif t ==	"deny" then
		Set_count_dict("url_deny count")
		debug(ip,"url_deny")
		action_deny()
	else
	end
end
--debug("----------- STEP 5")

--- STEP 6
-- header 过滤(黑名单) [scanner]
if config_is_on("header_Mod") then
	local tb_mod = header_Mod or {}
	for i,v in ipairs(tb_mod) do
		if v.state == "on" then			
			if host_url_remath(v.hostname,v.url) then
				if remath(headers[v.header[1]],v.header[2],v.header[3]) then
					Set_count_dict(" black_header_method count")
				 	debug("<header error> ip "..ip,"header_deny")
				 	action_deny()
				 	break
				end
			end
		end
	end
end

--debug("----------- STEP 6")

--- STEP 7
-- useragent(黑名单)
if config_is_on("agent_Mod") then	
	local uagent_mod = useragent_Mod or {}
	for i, v in ipairs( uagent_mod ) do
		if v.state == "on" then
			--debug(i.." agent_Mod state is on")
			if remath(host,v.hostname[1],v.hostname[2]) then
				--debug("useragent host is ok")
				if remath(agent,v.useragent[1],v.useragent[2]) then
					Set_count_dict("agent_deny count")
					debug(i.." agent : "..agent.." ip : "..ip,"agent_deny")
					action_deny()
					break
				end
			end
		end
	end
end

--debug("----------- STEP 7")

--- STEP 8
-- cookie (黑名单)
if config_is_on("cookie_Mod") then
	local cookie = headers["cookie"] or "unknowncookie"
	local cookie_mod = cookie_Mod or {}
	for i, v in ipairs( cookie_mod ) do
		if v.state == "on" then
			if remath(host,v.hostname[1],v.hostname[2]) then
				if remath(cookie,v.cookie[1],v.cookie[2]) then
					Set_count_dict("cookie_deny count")
					debug(i.." "..cookie,"cookie_deny")
					action_deny()
					break
				end
			end
		end
	end
end

--debug("----------- STEP 8")

--- STEP 9
-- args (黑名单)
if config_is_on("args_Mod") then
	--debug("args_Mod is on")
	local args_mod = args_Mod or {}
	local args = ngx.unescape_uri(ngx.var.query_string)
	if args ~= nil then
		for i,v in ipairs(args_mod) do
			if v.state == "on" then
				--debug("args_Mod state is on "..i)
				if remath(host,v.hostname[1],v.hostname[2]) then			
					if remath(args,v.args[1],v.args[2]) then
						Set_count_dict("args_deny count")
						debug("args_Mod No : "..i.." _args = "..args,"args_deny")
						action_deny()
						break
					end
				end
			end
		end
	end
end
--debug("----------- STEP 9")

--- STEP 10
-- post (黑名单)
local function get_postargs()	
	ngx.req.read_body()
	local data = ngx.req.get_body_data()
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
	return data
end
if config_is_on("post_Mod") and method == "POST" then
	--debug("post_Mod is on")
	local post_mod = post_Mod or {}
	local postargs = get_postargs()
	if postargs ~= nil then
		for i,v in ipairs(post_mod) do
			if v.state == "on" then
				--debug(i.." post_mod state is on")
				if remath(host,v.hostname[1],v.hostname[2]) then				
					if remath(postargs,v.post[1],v.post[2]) then
						Set_count_dict("post_deny count")
						debug("post_Mod No : "..i,"post_deny")
						action_deny()
						break
					end
				end
			end
		end
	end
end

--debug("----------- STEP 10")

--- STEP 11
-- network_Mod 访问控制
local function check_network()
	--if ip == nil then return end
	local tb_networkMod = network_Mod or {}
	for i, v in ipairs( tb_networkMod ) do
		if v.state =="on" then
			if host_url_remath(v.hostname,v.url) then
				local mod_ip = ip.." network_Mod no "..i
				local ip_count = limit_ip_dict:get(mod_ip)
				if ip_count == nil then
					local pTime =  v.network.pTime or 10
					limit_ip_dict:set(mod_ip,1,pTime)
				else
					local maxReqs = v.network.maxReqs or 50
					if ip_count >= maxReqs then
						--debug("maxReqs is true")
						local blacktime = v.network.blackTime or 10*60
						ip_dict:safe_set(ip,mod_ip.." host: "..host,blacktime)
						return true
					else
					    limit_ip_dict:incr(mod_ip,1)
					end
				end
			end
		end
	end
end

if config_is_on("network_Mod") then
	if check_network() then
		debug("network_Mod  check_network true")
		action_deny()
	end
end

--debug("----------- STEP 11")