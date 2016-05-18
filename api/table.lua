

local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end

local _action = get_argByName("action")
local _tb = get_argByName("table")
local _key = get_argByName("key")

if _tb == "" then sayHtml_ext({code="table_error"}) end

local tb = _G[_tb]

if tb == nil then sayHtml_ext({code="tb_nil"}) end

if _action == "set" then

	

	--- realIpFrom_Mod 特殊处理
	if _tb == "realIpFrom_Mod" then
		local _value = get_argByName("value")
		local _value_type = get_argByName("value_type")
		--sayHtml_ext({value=_value,value_type=_value_type,key=_key,json=stringTojson(_value)})
		if _value_type == "table" then
			_value = stringTojson(_value)
		end
		tb[_key] = _value
		sayHtml_ext({_key=_value})
	end
	---

	_key = tonumber(_key)
	if _key ~= nil then
		local _value = get_argByName("value")
		local _value_type = get_argByName("value_type")
		if _value_type == "table" then
			_value = stringTojson(_value)
		end
		if _value ~= nil then
			tb[_key] = _value
		end
		sayHtml_ext({_key=_value})
	else
		sayHtml_ext({})
	end

elseif _action == "del" then

	local tb = _G[_tb]

	--- realIpFrom_Mod 特殊处理
	if _tb == "realIpFrom_Mod" then
		tb[_key]=nil
		sayHtml_ext({_key=tb[_key]})
	end
	---

	_key = tonumber(_key)
	if _key ~= nil then
		local re = table.remove(tb,_key)
		sayHtml_ext({_key=re})
	else
		sayHtml_ext({code="key_error"})
	end

elseif _action == "get" then

	local tb = _G[_tb]

	if _key == "count_key" then
		local cnt = 0
		for k,v in pairs(tb) do
			cnt = cnt+1
		end
		sayHtml_ext({count=cnt})
	elseif _key == "all_key" then
		sayHtml_ext(tb)
	else
		--- realIpFrom_Mod 特殊处理
		if _tb == "realIpFrom_Mod" then
			sayHtml_ext({value=tb[_key]})
		end
		_key = tonumber(_key)
		sayHtml_ext({value=tb[_key]})
	end
		
	    

else
	sayHtml_ext({code="action_error"})
end

