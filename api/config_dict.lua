
local cjson_safe = require "cjson.safe"

local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end

local _action = get_argByName("action")
local _key = get_argByName("key")
local _value = get_argByName("value")
local tmpdict = ngx.shared.config_dict

if _action == "get" then

	if _key == "count_key" then
		local _tb = tmpdict:get_keys(0)
		sayHtml_ext(table.getn(_tb))
	elseif _key == "all_key" then
		local _tb,tb_all = tmpdict:get_keys(0),{}
		for i,v in ipairs(_tb) do
			tb_all[v] = tmpdict:get(v)
		end
		sayHtml_ext(tb_all)
	elseif _key == "" then
		local _tb = tmpdict:get_keys(1024)
		sayHtml_ext(_tb)
	else
		sayHtml_ext(tmpdict:get(_key))
	end

elseif _action == "set" then

	local tmp_value = cjson_safe.decode(_value)
	if type(tmp_value) == "table" then
		local _old_value = cjson_safe.decode(tmpdict:get(_key))
		local re = tmpdict:replace(_key,_value)
		sayHtml_ext({replace=re,old_value=_old_value,new_value=tmp_value})
	else
		sayHtml_ext({code="error",msg="value to json error"})
	end

else
	sayHtml_ext({code="error",msg="action is error"})
end