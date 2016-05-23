
local Config = {}
local cjson_safe = require "cjson.safe"
--- config.json 文件绝对路径
local config_json = "/opt/openresty/openstar/config.json"

--- 读取文件（全部读取）
local function readfile(filepath)
	local fd = io.open(filepath,"r")
	if fd == nil then return end -- 文件读取错误返回
    local str = fd:read("*a") --- 全部内容读取
    fd:close()
    return str
end

--- 载入JSON文件
local function loadjson(_path_name)
	local x = readfile(_path_name)
	return cjson_safe.decode(x)
end

--- 载入config.json全局基础配置
function loadConfig()
	local _jsonConfig = loadjson(config_json)
	if type(_jsonConfig) == "table" then 
		for k,v in pairs(_jsonConfig) do
			Config[k]=v
		end
	end
	Config.name = "localConfig"
	local _basedir = Config.jsonPath
	Config.json_realIpFrom_Mod = loadjson(_basedir.."realIpFrom_Mod.json")
	Config.json_ip_Mod = loadjson(_basedir.."ip_Mod.json")
	Config.json_host_method_Mod = loadjson(_basedir.."host_method_Mod.json")
	Config.json_app_Mod = loadjson(_basedir.."app_Mod.json")
	Config.json_referer_Mod = loadjson(_basedir.."referer_Mod.json")
	Config.json_url_Mod = loadjson(_basedir.."url_Mod.json")	
	Config.json_header_Mod = loadjson(_basedir.."header_Mod.json")	
	Config.json_useragent_Mod = loadjson(_basedir.."useragent_Mod.json")	
	Config.json_cookie_Mod = loadjson(_basedir.."cookie_Mod.json")
	Config.json_args_Mod = loadjson(_basedir.."args_Mod.json")
	Config.json_post_Mod = loadjson(_basedir.."post_Mod.json")	
	Config.json_network_Mod = loadjson(_basedir.."network_Mod.json")
	Config.json_replace_Mod = loadjson(_basedir.."replace_Mod.json")
end

loadConfig()

--- 使用全局变量 或 使用共享内存在做序列化 未做性能测试 后续测试后 使用较高性能的方法
--- 暂时将这些table使用全局变量 ，已经预留了共享内存的方式

	realIpFrom_Mod = Config.json_realIpFrom_Mod
	ip_Mod = Config.json_ip_Mod	
	host_method_Mod = Config.json_host_method_Mod
	app_Mod = Config.json_app_Mod
	referer_Mod = Config.json_referer_Mod
	url_Mod = Config.json_url_Mod
	header_Mod = Config.json_header_Mod		
	useragent_Mod = Config.json_useragent_Mod	
	cookie_Mod = Config.json_cookie_Mod
	args_Mod = Config.json_args_Mod
	post_Mod = Config.json_post_Mod
	network_Mod = Config.json_network_Mod
	replace_Mod = Config.json_replace_Mod
--- 将全局配置参数存放到共享内存（config_dict）中
	local config_dict = ngx.shared.config_dict
	for k,v in pairs(Config) do
		if type(v) == "table" then
			v = cjson_safe.encode(v)
		end
		config_dict:safe_set(k,v,0)
	end

--- 初始化ip_mod列表
--- 
local function set_ip_mod()
		local tb_ip_mod = ip_Mod or {}
		local _dict = ngx.shared["ip_dict"]
		if not tb_ip_mod then return end
		for i,v in ipairs(tb_ip_mod) do
			if v.action == "allow" then
				_dict:safe_set(v.ip,"allow",0)
			elseif v.action == "deny" then
				_dict:safe_set(v.ip,"ip_mod deny",0)
			else
			end
		end
	end

	if Config["ip_Mod"] == "on" then
		set_ip_mod()
	end

-- table 相关
--
	function tableToString(obj)
	    local lua = ""  
	    local t = type(obj)  
	    if t == "number" then  
	        lua = lua .. obj  
	    elseif t == "boolean" then  
	        lua = lua .. tostring(obj)  
	    elseif t == "string" then  
	        lua = lua .. string.format("%q", obj)  
	    elseif t == "table" then  
	        lua = lua .. "{\n"  
	    for k, v in pairs(obj) do  
	        lua = lua .. "[" .. tableToString(k) .. "]=" .. tableToString(v) .. ",\n"  
	    end  
	    local metatable = getmetatable(obj)  
	        if metatable ~= nil and type(metatable.__index) == "table" then  
	        for k, v in pairs(metatable.__index) do  
	            lua = lua .. "[" .. tableToString(k) .. "]=" .. tableToString(v) .. ",\n"  
	        end  
	    end  
	        lua = lua .. "}"  
	    elseif t == "nil" then  
	        return nil  
	    else  
	        error("can not tableToString a " .. t .. " type.")  
	    end  
	    return lua  
	end

	function stringToTable(str)
		if str == nil then return {} end
	    local ret = loadstring("return "..str)()  
		return ret
	end

	function tableTojson(obj)
	    local json_text = cjson_safe.encode(obj)  
	    return json_text
	end

	function stringTojson(obj)
		local json = cjson_safe.decode(obj)  
	    return json
	end

-- count_dict(_key) 相关
function Set_count_dict(_key)
	if _key == nil then return end
	local count_dict = ngx.shared.count_dict; --- ngx 缓存
	local key_count = count_dict:get(_key)
	if key_count == nil then 
		count_dict:set(_key,1)
	else
		count_dict:incr(_key,1)
	end
end

--- ngx_find
function ngx_find(str)
	-- str = string.sub(str,"@ngx_time@",ngx.time())
	-- ngx.re.gsub 效率要比string.sub要好一点，参考openresty最佳实践
	str = ngx.re.gsub(str,"@ngx_time@",ngx.time())
	-- string.find 会走jit,所以就没有用ngx模块
	-- 当前情况下，对token仅是全局替换一次，请注意
	if string.find(str,"@token@") ~= nil then		
		str = ngx.re.gsub(str,"@token@",set_token())
	end	
	return str
end

-- sayHtml_ext(fileorhtml,ty)
	function sayHtml_ext(html,ty)	
		ngx.header.content_type = "text/html"
		if html == nil then 
			ngx.say("fileorhtml is nil")
	    	ngx.exit(200)
	    elseif type(html) == "table" then
	    	if ty == nil then	    		
	    		ngx.say(tableTojson(html))
	    		ngx.exit(200)
	    	else
	    		ngx.say(tableToString(html))
	    		ngx.exit(200)
	    	end
	    else
		    ngx.say(ngx_find(html))
		    ngx.exit(200)
		end	
	end

	function sayFile(filename)
		ngx.header.content_type = "text/html"
		local str = readfile(Config.htmlPath..filename)
		if str == nil then str = filename end
		ngx.say(str)
		ngx.exit(200)
	end

	function sayLua(lua)
		local re = dofile(Config.htmlPath..lua)
		--debug("sayLua  init re :"..tostring( re ))
		return re
	end

-- writefile(filepath,msg,ty)  默认追加方式写入
--
	function writefile(filepath,msg,ty)
		if ty == nil then ty = "ab" end
	    local fd = io.open(filepath,ty) --- 默认追加方式写入
	    if fd == nil then return end -- 文件读取错误返回
	    fd:write(tostring(msg).."\n")
	    fd:flush()
	    fd:close()
	end

-- init_debug(msg) 阶段调试记录LOG
--
	function init_debug(msg)
		if Config.debug_Mod == false then return end  --- 判断debug开启状态
		local filepath = Config.logPath.."debug.log"
		local time = ngx.localtime()
		if type(msg) == "table" then
			local str_msg = tableToString(msg)
			writefile(filepath,time.."--init_debug: "..tostring(str_msg))
		else
			writefile(filepath,time.."--init_debug: "..tostring(msg))
		end
	end

-- debug(msg,filename) 记录debug日志
--
	function debug(msg,filename)
		if Config.debug_Mod == false then return end --- 判断debug开启状态
		if filename == nil then
			filename = "debug"
		end
		local filepath = Config.logPath..filename..".log"
		--init_debug(filepath)
		local host = ngx.req.get_headers()["Host"] or "unknow_host"
		local url = ngx.var.uri or "unknow_url"
		local method=ngx.req.get_method() or "unknow_method"
		local request_uri = ngx.var.request_uri or "unknow_req_uri"
		local time = os.date("%Y/%m/%d %H:%M:%S", os.time())
		local str = string.format("Host:%s method:%s url:%s debug:%s",host,method,url,msg)
		writefile(filepath,time..": "..str)
	end

-- action_deny(code) 拒绝访问
-- 
	function action_deny(code)
		if code == nil or type(code) ~= "number" then
			local default = [[<!DOCTYPE html><html><head><title>Error</title><style>body {width: 35em;margin: 0 auto;font-family: Tahoma, Verdana, Arial, sans-serif;}</style></head><body><h1>An error occurred.</h1><p>Sorry, the page you are looking for is currently unavailable.<br/>Please try again later.</p><p>If you are the system administrator of this resource then you should checkthe <a href="http://nginx.org/r/error_log">error log</a> for details.</p><p><em>Faithfully yours, nginx.</em></p></body></html>]]
			local msg = Config.sayHtml or default
			ngx.say(msg) 
			return ngx.exit(200)
		else
			return ngx.exit(code)
		end
	end

-- guid() 局部函数用于生成唯一随机字符串
local function guid()
    local random = require "resty-random"
    return string.format('%s-%s',
        random.token(10),
        random.token(10)
    )
end

-- 设置token 并缓存3分钟
function set_token(token)	
	if token == nil then token = guid()	end -- 没有值自动生成一个guid
	local ditc_token = ngx.shared.token_list;
	if ditc_token:get(token) == nil then 
		ditc_token:set(token,true,3*60)  --- -- 缓存3分钟 非重复插入
		return token
	else
		return set_token(nil)
	end	
end