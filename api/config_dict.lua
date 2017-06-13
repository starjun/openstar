
---- config_dict 操作 增删该查
--   包含模块
--   base realIpFrom_Mod deny_Msg [序号非数字]
--   uri_Mod header_Mod useragent_Mod cookie_Mod args_Mod post_Mod
--   network_Mod replace_Mod host_method_Mod rewrite_Mod app_Mod referer_Mod

local cjson_safe = require "cjson.safe"
local optl = require("optl")

local get_argsByName = optl.get_argsByName

local _action = get_argsByName("action")
local _mod = get_argsByName("mod")
local _id = get_argsByName("id")
local _value = get_argsByName("value")
local _value_type = get_argsByName("value_type")

local config_dict = ngx.shared.config_dict
local config = cjson_safe.decode(config_dict:get("config")) or {}
local config_base = config.base or {}


local _code = "ok"
if _action == "get" then

	if _mod == "all_mod" then
		local tmp_config = {}
		for k,v in pairs(config) do
			tmp_config[k] = cjson_safe.encode(v)
		end
		tmp_config.code = _code
		optl.sayHtml_ext(tmp_config)

	elseif _mod == "" then-- 显示所有 keys 的 name
		local tmp_config = {}
		for k,v in pairs(config) do
			table.insert(tmp_config,k)
		end
		tmp_config.code = _code
		optl.sayHtml_ext(tmp_config)

	else
		local _tb = config[_mod]
		if _tb == nil then optl.sayHtml_ext({code="error",msg="mod is Non-existent"}) end
		if _id == "" then
			_tb.state = config_base[_mod]
			_tb.code = _code
			optl.sayHtml_ext(_tb)

		elseif _id == "count_id" then
			local cnt = 0
			for k,v in pairs(_tb) do
				cnt = cnt+1
			end
			optl.sayHtml_ext({code=_code,count_id=cnt})
		else
			--- realIpFrom_Mod 和 base 和 denyHost_Mod 特殊处理
			if _mod ~= "realIpFrom_Mod" and _mod ~= "base" and _mod ~= "denyMsg" then
				_id = tonumber(_id) or 1
			end
			optl.sayHtml_ext({code=_code,msg=_tb[_id]})
		end

	end	

elseif _action == "set" then

	local _tb = config[_mod]
	if _tb == nil then optl.sayHtml_ext({code="error",msg="mod is Non-existent"}) end

	if _id == "" then -- id 参数不存在 （整体set）
		local tmp_value = cjson_safe.decode(_value)--将value参数的值 转换成table
		if type(tmp_value) == "table" then
			local _old_value = _tb
			config[_mod] = tmp_value
			local re = config_dict:replace("config",cjson_safe.encode(config))--将对应mod整体进行替换
			if re ~= true then
				_code = "error"
				optl.sayHtml_ext({code=_code,msg="replace error"})
			end
			config_dict:incr("config_version",1)
			optl.sayHtml_ext({code=_code,old_value=_old_value,new_value=tmp_value})
		else
			optl.sayHtml_ext({code="error",msg="value to json error"})
		end
	else		
		if _value_type == "json" then
			_value = cjson_safe.decode(_value) ---- 将value参数的值 转换成json/table
			if type(_value) ~= "table" then
				optl.sayHtml_ext({code="error",msg="value to json error"})
			end			
		end		
		--- realIpFrom_Mod base denyMsg 特殊处理
		if _mod ~= "realIpFrom_Mod" and _mod ~= "base" and _mod ~= "denyMsg" then
			_id = tonumber(_id)
		end
		local _old_value = _tb[_id]
		--- 判断id是否存在
		if _old_value == nil then optl.sayHtml_ext({code="error",msg="id is nil"}) end

		config[_mod][_id] = _value
		local re = config_dict:replace("config",cjson_safe.encode(config))
		if re ~= true then
			_code = "error"
			optl.sayHtml_ext({code=_code,msg="replace error"})
		end
		config_dict:incr("config_version",1)
		optl.sayHtml_ext({code=_code,old_value=_old_value,new_value=_value})

	end

elseif _action == "add" then

	local _tb = config[_mod]
	if _tb == nil then 
		optl.sayHtml_ext({code="error",msg="mod is Non-existent"}) 
	end

	if _value_type == "json" then
		_value = cjson_safe.decode(_value) ---- 将value参数的值 转换成json/table
		if type(_value) ~= "table" then
			optl.sayHtml_ext({code="error",msg="value to json error"})
		end
	end
	
	if _mod == "realIpFrom_Mod"  or _mod == "denyMsg" then
		if _tb[_id] == nil and _id ~= "" then
			config[_mod][_id] = _value
			local re = config_dict:replace("config",cjson_safe.encode(config))
			if re ~= true then
				_code = "error"
				optl.sayHtml_ext({code=_code,msg="replace error"})
			end
			config_dict:incr("config_version",1)
			optl.sayHtml_ext({code=_code,msg=_mod,value=_value})
		else
		 	optl.sayHtml_ext({code="error",msg="id is existent"})
		end 
		
	elseif  _mod == "base" then
		optl.sayHtml_ext({code="error",msg="base does not support add"})
	else
		table.insert(config[_mod],_value)
		local re = config_dict:replace("config",cjson_safe.encode(config))
		if re ~= true then
			_code = "error"
			optl.sayHtml_ext({code=_code,msg="replace error"})
		end
		config_dict:incr("config_version",1)
		optl.sayHtml_ext({code=_code,msg=_mod,value=_value})
	end
	
elseif _action == "del" then
	
	-- 判断mod 是否存在
	local _tb = config[_mod]
	if _tb == nil then optl.sayHtml_ext({code="error",msg="mod is Non-existent"}) end

	if _mod == "realIpFrom_Mod" or _mod == "denyMsg" then
		if _tb[_id] == nil then
			optl.sayHtml_ext({code="error",msg="id is Non-existent"})
		else
			config[_mod][_id] = nil
			local re = config_dict:replace("config",cjson_safe.encode(config))
			if re ~= true then
				_code = "error"
				optl.sayHtml_ext({code=_code,msg="replace error"})
			end
			config_dict:incr("config_version",1)
			optl.sayHtml_ext({code=_code,mod=_mod,id=_id})
		end
	elseif _mod == "base" then
		optl.sayHtml_ext({code="error",msg="base does not support del"})
	else
		_id = tonumber(_id)
		if _id == nil then
			optl.sayHtml_ext({code="error",msg="_id is not number"})
		else
			local rr = table.remove(config[_mod],_id)
			if rr == nil then
				optl.sayHtml_ext({code="error",msg="id is Non-existent"})
			else
				local re = config_dict:replace("config",cjson_safe.encode(config))
				if re ~= true then
					_code = "error"
					optl.sayHtml_ext({code=_code,msg="replace error"})
				end
				config_dict:incr("config_version",1)
				optl.sayHtml_ext({code=_code,mod=_mod,id=_id})
			end		
		end			
	end

else
	optl.sayHtml_ext({code="error",msg="action error"})
end