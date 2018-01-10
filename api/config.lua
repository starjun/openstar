
----  配置json相关操作
--    包括 base.json conf_json/* 所有json
--    所以就有权限相关问题，请检测 openstar 目录写 因为要写base.json
--    请检测 conf_json/host_json 目录是否存在 并有写权限 和 conf_json 目录是否有写权限
--    配置json的重新载入
--    内存配置保存到对应json文件

local cjson_safe = require "cjson.safe"
local optl = require("optl")
local JSON = require("JSON")

local get_argsByName = optl.get_argsByName
local sayHtml_ext = optl.sayHtml_ext

local _action = get_argsByName("action")
local _mod = get_argsByName("mod")
local _debug = get_argsByName("debug")
local _host = get_argsByName("host")

local host_dict = ngx.shared.host_dict
local config_dict = ngx.shared.config_dict
local ip_dict = ngx.shared.ip_dict

local config = cjson_safe.decode(config_dict:get("config")) or {}

local config_base = config.base or {}

local function list_to_str(_list)
	local re = ""
	for _,v in ipairs(_list) do
		re = re..v.."\n"
	end
	return re
end

local function config_save()
	local re
	for k,v in pairs(config) do
		if _debug == "no" then
			re = optl.writefile(config_base.jsonPath..k..".json",JSON:encode_pretty(v),"w+")
		else
			re = optl.writefile(config_base.jsonPath..k.."_bak.json",JSON:encode_pretty(v),"w+")
		end		
		if not re then break end
	end
	return re
end

local function hostMod_save(_hostname)
	_hostname = _hostname or ""
	local tb_host_mod ={}
	local _hostDict_all,_host_Mod = host_dict:get_keys(0),{}
	for i,v in ipairs(_hostDict_all) do
		local from , to = string.find(v, "_HostMod$")
		if from == nil then
			local tmp_tb = {}
			tmp_tb[1],tmp_tb[2] = v,host_dict:get(v)
			table.insert(_host_Mod, tmp_tb)
			if _hostname == "" then
				tb_host_mod[v] = host_dict:get(v.."_HostMod") or "{}"
			elseif _hostname == v then
				tb_host_mod[v] = host_dict:get(v.."_HostMod") or "{}"
			end
		end
	end

	local json_host_Mod = JSON:encode_pretty(_host_Mod)

	local re
	if _debug == "no" then
		re = optl.writefile(config_base.jsonPath.."host_json/host_Mod.json",json_host_Mod,"w+")
		if not re then
			return false
		end
		for k,v in pairs(tb_host_mod) do
			local tmp_v = optl.stringTojson(v)
			re = optl.writefile(config_base.jsonPath.."host_json/"..k..".json",JSON:encode_pretty(tmp_v),"w+")
			if not re then
				return false
			end
		end
	else
		re = optl.writefile(config_base.jsonPath.."host_json/host_Mod_bak.json",json_host_Mod,"w+")
		if not re then
			return false
		end
		for k,v in pairs(tb_host_mod) do
			local tmp_v = optl.stringTojson(v)
			re = optl.writefile(config_base.jsonPath.."host_json/"..k.."_bak.json",JSON:encode_pretty(tmp_v),"w+")
			if not re then
				return false
			end
		end
	end
	return true
end

local function ip_dict_save()
	local _tb_ip_name = ip_dict:get_keys(0)
	local allowIp,denyIp,logIp = {},{},{}
	for _,v in ipairs(_tb_ip_name) do
		local ip_value = ip_dict:get(v)
		--- init 中，永久ip只有这3个value
		if ip_value == "allow" then
			table.insert(allowIp,v)
		elseif ip_value == "deny" then
			table.insert(denyIp,v)
		elseif ip_value == "log" then
			table.insert(logIp,v)
		end
	end
	local _str_ending = ".ip.bak"
	if _debug == "no" then
		_str_ending = ".ip"
	end
	-- 保存3个文件 暂时不检查每次的保存情况
	local re
	re = optl.writefile(config_base.jsonPath.."ip/allow".._str_ending,list_to_str(allowIp),"w+")
	re = optl.writefile(config_base.jsonPath.."ip/deny".._str_ending,list_to_str(denyIp),"w+")
	re = optl.writefile(config_base.jsonPath.."ip/log".._str_ending,list_to_str(logIp),"w+")
	return re
end

if _action == "save" then

	if _mod == "all_Mod" then

		local _code = "ok"
		local _msg = "save ok"

		local re = config_save()
		if not re then
			_code = "error" 
			_msg = "config_dic save error"
			sayHtml_ext({code=_code,msg=_msg,debug=_debug})
		end
		
		re = hostMod_save()
		if not re then
			_code = "error"
			_msg = "host_dict save error"
		end

		re = ip_dict_save()
		if not re then
			_code = "error"
			_msg = "ip_dict save error"
		end

		sayHtml_ext({code=_code,msg=_msg,debug=_debug})

	elseif _mod == "host_Mod" then
		local re = hostMod_save(_host)
		if re then
			sayHtml_ext({code="ok",msg="host_dict save ok",debug=_debug})
		else
			sayHtml_ext({code="error",msg="host_dict save error",debug=_debug})
		end

	elseif _mod == "ip_Mod" then
		local  re = ip_dict_save()
		if re then
			local _msg = "ip_dict save ok"
			optl.sayHtml_ext({code="ok",msg=_msg,debug=_debug})
		else
			local _msg = "ip_dict save error"
			optl.sayHtml_ext({code="error",msg=_msg,debug=_debug})
		end

	else
		local _msg = config[_mod]
		local re
		local _code = "ok"
		if not _msg then
			sayHtml_ext({code="error",msg="mod is Non-existent",debug=_debug})
		end

		if _debug == "no" then
			re = optl.writefile(config_base.jsonPath.._mod..".json",JSON:encode_pretty(_msg),"w+")
		else
			re = optl.writefile(config_base.jsonPath.._mod.."_bak.json",JSON:encode_pretty(_msg),"w+")
		end

		if not re then
			_code = "error"
		end
		optl.sayHtml_ext({code=_code,msg=_msg,debug=_debug})

	end

elseif _action =="reload" then

	loadConfig()
	--ngx.say("it is ok")
	sayHtml_ext({code="ok",msg="reload ok"})

else
    sayHtml_ext({code="error",msg="action is Non-existent"})
end


