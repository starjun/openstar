
local cjson_safe = require "cjson.safe"

local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end

local _action = get_argByName("action")
local _mod = get_argByName("mod")
local _id = get_argByName("id")
local _value = get_argByName("value")
local tmpdict = ngx.shared.config_dict

if _action == "get" then

	if _mod == "" then
		local _tb,tb_all = tmpdict:get_keys(0),{}
		for i,v in ipairs(_tb) do
			tb_all[v] = tmpdict:get(v)
		end
		sayHtml_ext(tb_all)
	elseif _mod == "count_mod" then
		local _tb = tmpdict:get_keys(0)
		sayHtml_ext(table.getn(_tb))
	elseif _mod == "mod" then
		local _tb = tmpdict:get_keys(0)
		sayHtml_ext(_tb)
	else	
		local _tb = tmpdict:get(_mod)
		if _tb == nil then sayHtml_ext({code="error",msg="mod is nil"}) end
		_tb = cjson_safe.decode(_tb) or {}
		if _id == "" then
			sayHtml_ext(_tb)
		elseif _id == "count_id" then
			local cnt = 0
			for k,v in pairs(_tb) do
				cnt = cnt+1
			end
			sayHtml_ext({count=cnt})
		else
			--- realIpFrom_Mod 特殊处理
			if _mod ~= "realIpFrom_Mod" then
				_id = tonumber(_id)
			end			
			sayHtml_ext({value=_tb[_id]})
		end
	end
	
elseif _action == "set" then

	if _mod ~= "" then
		local _tb = tmpdict:get(_mod)
		if _tb == nil then sayHtml_ext({code="error",msg="mod is nil"}) end
		if _id == "" then
			local tmp_value = cjson_safe.decode(_value)
			if type(tmp_value) == "table" then
				local _old_value = cjson_safe.decode(tmpdict:get(_mod))
				local re = tmpdict:replace(_mod,_value)
				sayHtml_ext({replace=re,old_value=_old_value,new_value=tmp_value})
			else
				sayHtml_ext({code="error",msg="value to json error"})
			end
		else			
			_tb = cjson_safe.decode(_tb) or {}
			local tmp_value = cjson_safe.decode(_value)
			if type(tmp_value) == "table" then
				local _old_value = cjson_safe.decode(_tb[_id])
				--- realIpFrom_Mod 特殊处理
				if _mod ~= "realIpFrom_Mod" then
					_id = tonumber(_id)
				end
				_tb[_id] = tmp_value
				local re = tmpdict:replace(_mod,cjson_safe.encode(_tb))
				sayHtml_ext({replace=re,old_value=_old_value,new_value=tmp_value})
			else
				sayHtml_ext({code="error",msg="value to json error"})
			end				

		end
	else
		sayHtml_ext({code="error",msg="mod error"})
	end

else
	sayHtml_ext({code="error",msg="action error"})
end