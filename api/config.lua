
----  配置json相关操作
--    包括 base.json conf_json/* 所有json
--    配置json的重新载入
--    内存配置保存到对应json文件

local cjson_safe = require "cjson.safe"
local optl = require("optl")

local get_argsByName = optl.get_argsByName
local sayHtml_ext = optl.sayHtml_ext

local _action = get_argsByName("action")
local _mod = get_argsByName("mod")
local _debug = get_argsByName("debug")

local config_dict = ngx.shared.config_dict
local host_dict = ngx.shared.host_dict

local _tb,config = config_dict:get_keys(0),{}
for i,v in ipairs(_tb) do
	config[v] = config_dict:get(v)
end

local config_base = cjson_safe.decode(config_dict:get("base")) or {}

local function  hostMod()
	local _tb_host,tb_host_mod,tb_host_name = host_dict:get_keys(0),{},{}
	for i,v in ipairs(_tb_host) do
		local from , to = string.find(v, "_HostMod")
		if from == nil then
			local tmp_tb = {}
			tmp_tb[1],tmp_tb[2] = v,host_dict:get(v)
			table.insert(tb_host_name, tmp_tb)
			tb_host_mod[v] = host_dict:get(v.."_HostMod")
		end
	end
	--optl.sayHtml_ext({_tb_host=_tb_host,tb_host_mod=tb_host_mod,tb_host_name=tb_host_name})
	local j_tb_host_name = optl.tableTojson(tb_host_name)

	local re
	if _debug == "no" then
		re = optl.writefile(config_base.jsonPath.."host_json/host_Mod.json",j_tb_host_name,"w+")
		if re ~= true then
			return false
		end
		for i,v in ipairs(tb_host_name) do
			re = optl.writefile(config_base.jsonPath.."host_json/"..v[1]..".json",tb_host_mod[v[1]],"w+")
			if re ~= true then
				return false
			end
		end
	else
		re = optl.writefile(config_base.jsonPath.."host_json/host_Mod_bak.json",j_tb_host_name,"w+")
		if re ~= true then
			return false
		end
		for i,v in ipairs(tb_host_name) do
			re = optl.writefile(config_base.jsonPath.."host_json/"..v[1].."_bak.json",tb_host_mod[v[1]],"w+")
			if re ~= true then
				return false
			end
		end
	end
	return true
end

if _action == "save" then

	local re
	local _code = "ok"
	if _mod == "all_mod" then
		for k,v in pairs(config) do
			if k == "base" then
				if _debug == "no" then
					re = optl.writefile(config_base.baseDir..k..".json",v,"w+")
				else
					re = optl.writefile(config_base.baseDir..k.."_bak.json",v,"w+")
				end
			elseif k == "denyMsg" then
				if _debug == "no" then
					re = optl.writefile(config_base.jsonPath..k..".json",v,"w+")
				else
					re = optl.writefile(config_base.jsonPath..k.."_bak.json",v,"w+")
				end
			else
				if _debug == "no" then
					re = optl.writefile(config_base.jsonPath..k..".json",v,"w+")
				else
					re = optl.writefile(config_base.jsonPath..k.."_bak.json",v,"w+")
				end
			end
			if re ~= true then break end
		end
		local _code = "ok"
		local _msg = "save ok"
		if re ~= true then  
			_code = "error" 
			_msg = "config_dic save error"
			sayHtml_ext({code=_code,msg=_msg})
		end
		
		re = hostMod()
		if re ~= true then  
			_code = "error"
			_msg = "host_dict save error"
		end
		sayHtml_ext({code=_code,msg=_msg})

	else
		local msg = config[_mod]
		local re
		if not msg and _mod ~= "host_Mod" then 
			sayHtml_ext({code="error",msg="mod is Non-existent"}) 
		end
		if _mod == "base" then
			if _debug == "no" then
				re = optl.writefile(config_base.baseDir.._mod..".json",msg,"w+")
			else
				re = optl.writefile(config_base.baseDir.._mod.."_bak.json",msg,"w+")
			end
		elseif _mod == "host_Mod" then
			re = hostMod()
		else
			if _debug == "no" then
				re = optl.writefile(config_base.jsonPath.._mod..".json",msg,"w+")
			else
				re = optl.writefile(config_base.jsonPath.._mod.."_bak.json",msg,"w+")
			end
		end
		if re ~= true then
			_code = "error"
		end
		optl.sayHtml_ext({code=_code,msg=msg})

	end

elseif _action =="reload" then

	loadConfig()
	--ngx.say("it is ok")
	sayHtml_ext({code="ok",msg="reload ok"})
else
    sayHtml_ext({code="error",msg="action is Non-existent"})
end


