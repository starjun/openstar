-----  access_all by zj  -----

if ngx.req.is_internal() then return end

local ngx_var = ngx.var
local ngx_unescape_uri = ngx.unescape_uri

local remoteIp = ngx_var.remote_addr
local headers = ngx.req.get_headers()

local host = ngx_unescape_uri(ngx_var.http_host)
local referer = ngx_unescape_uri(ngx_var.http_referer)
local agent = ngx_unescape_uri(ngx_var.http_user_agent)

local method = ngx_unescape_uri(ngx_var.request_method)
local url = ngx_unescape_uri(ngx_var.uri)
local request_url = ngx_unescape_uri(ngx_var.request_uri)

local base_msg = {}
	base_msg.remoteIp = remoteIp
	base_msg.host = host
	base_msg.method = method
	base_msg.request_url = request_url
	base_msg.url = url
	base_msg.agent = agent
	base_msg.referer = referer

local config_dict = ngx.shared.config_dict
local limit_ip_dict = ngx.shared.limit_ip_dict
local ip_dict = ngx.shared.ip_dict
local count_dict = ngx.shared.count_dict
local token_dict = ngx.shared.token_dict
local host_dict = ngx.shared.host_dict

local cjson_safe = require "cjson.safe"
local config_base = cjson_safe.decode(config_dict:get("base")) or {}

base_msg.config_base = config_base

local optl = require("optl")

local host_Mod_state = host_dict:get(host)

--- 2016年8月4日 增加全局Mod开关
--  增加基于host的过滤模块开关判断
if config_base["Mod_state"] == "off" or host_Mod_state == "off" then
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

--- remath(str,re_str,options)
--- 常用二阶匹配规则
local remath = optl.remath

-- 传入 (host)
-- ipfromset.ips 异常处理
local function loc_getRealIp(_host)
	if config_is_on("realIpFrom_Mod") then
		local realipfrom = getDict_Config("realIpFrom_Mod")
		local ipfromset = realipfrom[_host]
		if type(ipfromset) ~= "table" or type(ipfromset.ips) ~= "table" then 
			return remoteIp 
		end
		if remath(remoteIp,ipfromset.ips[1],ipfromset.ips[2]) then
			--- header 中key名称 - 需要转换成 _
			local x = 'http_'..ngx.re.gsub(tostring(ipfromset.realipset),'-','_')
        	local ip = ngx_unescape_uri(ngx_var[x])
        	if ip == "" then
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

--- 匹配 host 和 url
local function host_url_remath(_host,_url)
	if _host == nil or _url == nil then
		return false
	end
	if remath(host,_host[1],_host[2]) and remath(url,_url[1],_url[2]) then
		return true
	end
end

--- 获取单个args值
local get_argsByName = optl.get_argsByName

--- 拦截计数 2016年6月7日 21:52:52 up 从全局变成local
local Set_count_dict = optl.set_count_dict

-- action_deny(code) 拒绝访问
local function action_deny()
	-- 2016年9月19日
	-- 增加Mod_state = log , host_Mod state = log
	-- 在拒绝请求都进行了log记录，仅ip黑名单的没有记录（因为量的问题），故可直接return
	if config_base["Mod_state"] == "log" or host_Mod_state == "log" then
		return
	end
	if config_base.denyMsg.state == "on" then
		local tb = getDict_Config("denyMsg")
		local host_deny_msg = tb[host] or {}
		local tp_denymsg = type(host_deny_msg.deny_msg)
		if tp_denymsg == "number" then
			ngx.exit(host_deny_msg.deny_msg)
		elseif tp_denymsg == "string" then
			ngx.say(host_deny_msg.deny_msg)
			ngx.exit(200)
		end
	end
	if type(config_base.denyMsg.msg) == "number" then
		ngx.exit(config_base.denyMsg.msg)
	else
		ngx.say(tostring(config_base.denyMsg.msg))
		ngx.exit(200)
	end
end

-- 获取所有post的内容
local get_postargs = optl.get_posts

local post_date
local get_date

--- STEP 0
local ip = loc_getRealIp(host)
base_msg.ip = ip
-- debug 调试，线上请注释 没有传递filename 默认就是debug.log
-- optl.debug(base_msg,"---- STEP 0 ----")

--- STEP 0.1
-- 2016年7月29日19:14:31  检查
if host == "" then 
	Set_count_dict("host_method deny count")
	optl.debug(base_msg,"deny","host_method.log")
	ngx.exit(404)
end

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
	 		optl.debug(base_msg,"log","ip.log")
		else
			Set_count_dict(ip)
			action_deny()
		end
	end
	-- 基于host的ip黑白名单 eg:www.abc.com-101.111.112.113
	local host_ip = ip_dict:get(host.."-"..ip)
	if host_ip ~= nil then
		if host_ip == "allow" then -- 跳出后续规则
			return
		elseif host_ip == "log" then 
			Set_count_dict(host.."-ip log count")
	 		optl.debug(base_msg,"log",host..".log")
		else
			Set_count_dict(host.."-"..ip)
			action_deny()
		end
	end
end

---  STEP 2
-- host and method  访问控制(白名单)
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
		Set_count_dict("host_method deny count")
	 	optl.debug(base_msg,"deny","host_method.log")
	 	action_deny()
	end
end

--- STEP 3
-- rewrite 跳转阶段(set-cookie)
-- 本来想着放到rewrite阶段使用的，方便统一都放到access阶段了。
if config_is_on("rewrite_Mod") then
	local tb_mod = getDict_Config("rewrite_Mod")
	for i,v in ipairs(tb_mod) do
		if v.state == "on" and host_url_remath(v.hostname,v.url) then

			if v.action[1] == "set-cookie" then
				local token = ngx.md5(v.action[2] .. ip)
	            if (ngx_var.cookie_token ~= token) then
	                ngx.header["Set-Cookie"] = {"token=" .. token}
	                if method == "POST" then
	                	return ngx.redirect(request_url,307)
	                else
	                	return ngx.redirect(request_url)
	                end
	            end
			elseif v.action[1] == "set-url" then
			-- 备用 使用url尾巴跳转方式进行验证
				
			end
			
		end
	end
end


--- STEP 4
-- host_Mod 规则过滤
-- 动作支持 （allow deny log）
if  host_Mod_state == "on" then
	local tb = cjson_safe.decode(host_dict:get(host.."_HostMod")) or {}
	local _action
	for i,v in ipairs(tb) do
		if v.state == "on" then
			if v.action[2] == "url" and remath(url,v.url[1],v.url[2]) then

				_action = v.action[1]				
				if _action == "deny" then
					Set_count_dict(host.." deny count")
					optl.debug(base_msg,"deny No: "..i,host..".log")
					action_deny()
					break
				elseif _action == "log" then
					Set_count_dict(host.." log count")
					optl.debug(base_msg,"log No: "..i,host..".log")
				elseif _action == "allow" then
					return
				end
				
			elseif v.action[2] == "referer" and remath(referer,v.referer[1],v.referer[2]) and remath(url,v.url[1],v.url[2]) then

				_action = v.action[1]
				if _action == "deny" then
					Set_count_dict(host.." deny count")
					optl.debug(base_msg,"deny No: "..i,host..".log")
					action_deny()
					break
				elseif _action == "log" then
					Set_count_dict(host.." log count")
					optl.debug(base_msg,"log No: "..i,host..".log")
				elseif _action == "allow" then
					return
				end

			elseif v.action[2] == "useragent" and remath(agent,v.useragent[1],v.useragent[2]) then
				
				_action = v.action[1]
				if _action == "deny" then
					Set_count_dict(host.." deny count")
					optl.debug(base_msg,"deny No: "..i,host..".log")
					action_deny()
					break
				elseif _action == "log" then
					Set_count_dict(host.." log count")
					optl.debug(base_msg,"log No: "..i,host..".log")
				elseif _action == "allow" then
					return
				end

			elseif v.action[2] == "network" and remath(url,v.url[1],v.url[2]) then

				local mod_host_ip = ip.." host_network_Mod No "..i
				local ip_count = limit_ip_dict:get(mod_host_ip)
				if ip_count == nil then
					local pTime =  v.network.pTime or 10
					limit_ip_dict:set(mod_host_ip,1,pTime)
				else
					local maxReqs = v.network.maxReqs or 50
					if ip_count >= maxReqs then
						local blacktime = v.network.blackTime or 10*60
						ip_dict:safe_set(host.."-"..ip,mod_host_ip,blacktime)
						optl.debug(base_msg,"network_Mod  deny No : "..i,host..".log")
						-- network 触发直接拦截
						Set_count_dict(host.." deny count")
						action_deny()
						break
					else
					    limit_ip_dict:incr(mod_host_ip,1)
					end
				end

			end
		end
	end	
end

-- --- STEP 5
-- -- app_Mod 访问控制 （自定义action）
-- -- 目前支持的 deny allow log next rehtml refile relua relua_str cc
-- 2016年11月13日13:13:59 将原用于CC验证的next动作修改为cc，next同referer效果一样
-- 且验证args参数，非取第一个值验证，而是所有都验证
if config_is_on("app_Mod") then
	local app_mod = getDict_Config("app_Mod")
	for i,v in ipairs(app_mod) do
		if v.state == "on" and host_url_remath(v.hostname,v.url) then
				
			if v.action[1] == "deny" then
				Set_count_dict("app deny count")
				optl.debug(base_msg,"deny No : "..i,"app.log")
				action_deny()
				break

			elseif v.action[1] == "allow" then

				return

			elseif v.action[1] == "cc" then
			-- action = cc 用于cc验证，匹配成功跳出后续的rehtml的js跳转
			-- 后续增加多维度匹配就不用这么麻烦了

				if v.action[2] == "args" then
					-- 取args参数任意一个，修改仅取第一个
					local args_tb = ngx.req.get_uri_args()[v.args[3]]

					if type(args_tb) == "table" then
						local checkcc
						for _,vv in ipairs(args_tb) do
							if remath(vv,v.args[1],v.args[2]) then
								checkcc = true
								-- 也可使用 goto 代码
								break
							end
						end
						if checkcc then
							break
						end
					else
						if remath(args_tb,v.args[1],v.args[2]) then
							break
						end
					end
				else
					-- 预留给其他cc验证点，header、post_args等等					
				end

			elseif v.action[1] == "next" then
				--- base_msg 中的 remoteIp host referer agent method url request_url ip
				--- 以上是 next 动作可以匹配的http参数
				local check_next = v.action[2]				
				if remath(base_msg[check_next],v[check_next][1],v[check_next][2]) then
					-- pass 匹配成功 无操作
				else					
					Set_count_dict("app deny count")
					optl.debug(base_msg,"deny No : "..i,"app.log")
					action_deny()
					break
				end				

			elseif v.action[1] == "log" then
				local http_tmp = {}
				http_tmp["headers"] = headers
				get_date = ngx_unescape_uri(ngx_var.query_string)
				http_tmp["get_date"] = get_date
				if method == "POST" then
					post_date = get_postargs()
					http_tmp["post"] = post_date						
				end
				optl.debug(base_msg,"log Msg : "..optl.tableTojson(http_tmp),"app.log")

			elseif v.action[1] == "rehtml" then
				optl.sayHtml_ext(v.rehtml)
				break

			elseif v.action[1] == "refile" then
				optl.sayFile(config_base.htmlPath..v.refile)
				break

			-- 2016年10月27日 新增 动态执行lua字符串
			elseif v.action[1] == "relua_str" then
				local re_lua_do = loadstring(v.relua_str)
				if re_lua_do() == "break" then
					ngx.exit(200)					
				end

			elseif v.action[1] == "relua" then
				local re_saylua = optl.sayLua(config_base.htmlPath..v.relua)
				if re_saylua == "break" then
					ngx.exit(200)
				end

			elseif v.action[1] == "set" then -- 预留
				break
			else
				break
			end 
			
		end
	end
end

-- --- STEP 6
-- -- referer过滤模块
--  动作支持（allow deny log next）
if config_is_on("referer_Mod") then
	local ref_mod = getDict_Config("referer_Mod")
	for i, v in ipairs( ref_mod ) do
		if v.state == "on" and host_url_remath(v.hostname,v.url) then

			if v.action == "allow" then
				if remath(referer,v.referer[1],v.referer[2]) then
					return					
				end				
			elseif v.action == "next" then
				if remath(referer,v.referer[1],v.referer[2]) then
					-- pass 继续执行
				else
					Set_count_dict("referer deny count")
					optl.debug(base_msg,"deny  No : "..i,"referer.log")
					action_deny()
					break
				end				
			elseif v.action == "log" then
				if remath(referer,v.referer[1],v.referer[2]) then
					Set_count_dict("referer log count")
					optl.debug(base_msg,"log  No : "..i,"referer.log")
				end
			else
				if remath(referer,v.referer[1],v.referer[2]) then
					Set_count_dict("referer deny count")
					optl.debug(base_msg,"deny  No : "..i,"referer.log")
					action_deny()
					break
				end
			end
		end
	end
end

--- STEP 7
-- url 过滤(黑/白名单/log)
if config_is_on("url_Mod") then
	local url_mod = getDict_Config("url_Mod")
	for i, v in ipairs( url_mod ) do
		if v.state == "on" and host_url_remath(v.hostname,v.url) then

			if v.action == "allow" then --- 跳出后续规则
				return
			elseif v.action ==	"deny" then
				Set_count_dict("url deny count")
				optl.debug(base_msg,"deny No : "..i,"url.log")
				action_deny()
				break
			elseif v.action == "log" then
				Set_count_dict("url log count")
				optl.debug(base_msg,"log No : "..i,"url.log")
			end
			
		end
	end	
end

--- STEP 8
-- header 过滤(黑名单) [scanner]
if config_is_on("header_Mod") then
	local tb_mod = getDict_Config("header_Mod")
	for i,v in ipairs(tb_mod) do
		if v.state == "on" and host_url_remath(v.hostname,v.url) then

			if remath(headers[v.header[1]],v.header[2],v.header[3]) then
				Set_count_dict("header deny count")
			 	optl.debug(base_msg,"deny No : "..i,"header.log")
			 	action_deny()
			 	break
			end
			
		end
	end
end

--- STEP 9
-- useragent(黑、白名单/log记录)
if config_is_on("useragent_Mod") then	
	local uagent_mod = getDict_Config("useragent_Mod")
	for i, v in ipairs( uagent_mod ) do
		if v.state == "on" and remath(host,v.hostname[1],v.hostname[2]) then

			if remath(agent,v.useragent[1],v.useragent[2]) then
				if v.action == "allow" then
					return
				elseif v.action == "log" then
					Set_count_dict("agent log count")
					optl.debug(base_msg,"log No : "..i,"agent.log")					
				else
					Set_count_dict("agent deny count")
					optl.debug(base_msg,"deny No : "..i,"agent.log")
					action_deny()
					break
				end
			end
			
		end
	end
end

--- STEP 10
-- cookie (黑/白名单/log记录)
local cookie = ngx_var.http_cookie

if config_is_on("cookie_Mod") and cookie ~= nil then
	cookie = ngx_unescape_uri(cookie)
	local cookie_mod = getDict_Config("cookie_Mod")
	for i, v in ipairs( cookie_mod ) do
		if v.state == "on" and remath(host,v.hostname[1],v.hostname[2]) then

			if remath(cookie,v.cookie[1],v.cookie[2]) then
				if v.action == "deny" then
					Set_count_dict("cookie deny count")
					optl.debug(base_msg,"deny _cookie : "..cookie.." No : "..i,"cookie.log")
					action_deny()
					break
				elseif v.action =="log" then
					Set_count_dict("cookie log count")
					optl.debug(base_msg,"log _cookie : "..cookie.." No : "..i,"cookie.log")
				elseif v.action == "allow" then
					return
				end
			end

		end
	end
end

--- STEP 11
-- args [query_string] (黑/白名单/log记录)
if config_is_on("args_Mod") then
	--debug("args_Mod is on")
	local args_mod = getDict_Config("args_Mod")
	local args = get_date or ngx_unescape_uri(ngx_var.query_string)
	if args ~= "" then
		for i,v in ipairs(args_mod) do
			if v.state == "on" and remath(host,v.hostname[1],v.hostname[2]) then
			
				if remath(args,v.args[1],v.args[2]) then
					if v.action == "deny" then
						Set_count_dict("args deny count")
						optl.debug(base_msg,"deny _args = "..args.." No : "..i,"args.log")
						action_deny()
						break
					elseif v.action == "log" then
						Set_count_dict("args log count")
						optl.debug(base_msg,"log _args = "..args.." No : "..i,"args.log")							
					elseif v.action == "allow" then
						return							
					end
				end
				
			end
		end
	end
end

--- STEP 12
-- post (黑/白名单)

if config_is_on("post_Mod") and method == "POST" then
	local post_mod = getDict_Config("post_Mod")
	local postargs = post_date or get_postargs()
	if postargs ~= "" then
		for i,v in ipairs(post_mod) do
			if v.state == "on" and remath(host,v.hostname[1],v.hostname[2]) then

				if remath(postargs,v.post[1],v.post[2]) then
					if v.action == "deny" then
						Set_count_dict("post deny count")
						optl.debug(base_msg,"deny _post : "..postargs.."No : "..i,"post.log")
						action_deny()
						break
					elseif v.action == "log" then
						Set_count_dict("post log count")
						optl.debug(base_msg,"deny _post : "..postargs.."No : "..i,"post.log")							
					elseif v.action == "allow" then
						return
					end
				end
			end
		end
	end
end


--- STEP 13
-- network_Mod 访问控制
if config_is_on("network_Mod") then
	local tb_networkMod = getDict_Config("network_Mod")
	for i, v in ipairs( tb_networkMod ) do
		if v.state =="on" and host_url_remath(v.hostname,v.url) then

			local mod_ip = ip.." network_Mod No "..i
			local ip_count = limit_ip_dict:get(mod_ip)
			if ip_count == nil then
				local pTime =  v.network.pTime or 10
				limit_ip_dict:set(mod_ip,1,pTime)
			else
				local maxReqs = v.network.maxReqs or 50
				if ip_count >= maxReqs then
					local blacktime = v.network.blackTime or 10*60
					if v.hostname[2] == "" then
						if v.hostname[1] == "*" then
							ip_dict:safe_set(ip,mod_ip,blacktime)
						else
							ip_dict:safe_set(host.."-"..ip,mod_ip,blacktime)
						end
					elseif v.hostname[2] == "table" then
						for j,vj in ipairs(v.hostname[1]) do
							ip_dict:safe_set(vj.."-"..ip,mod_ip,blacktime)
						end
					elseif v.hostname[2] == "list" then
						for j,vj in pairs(v.hostname[1]) do
							ip_dict:safe_set(j.."-"..ip,mod_ip,blacktime)
						end
					else
						ip_dict:safe_set(host.."-"..ip,mod_ip,blacktime)
					end
					optl.debug(base_msg,"deny  No : "..i,"network.log")
					action_deny()
					--ngx.say("frist network deny")
					break
				else
				    limit_ip_dict:incr(mod_ip,1)
				end
			end
			
		end
	end
end

