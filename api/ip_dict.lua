
local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end

local _action = get_argByName("action")
local _id = get_argByName("id")
local _value = get_argByName("value")
local _time = tonumber( get_argByName("time")) or 0

local tmpdict = ngx.shared["ip_dict"]

local optl = require("optl")

-- 用于ip_dict操作接口  对ip列表进行增 删 改 查 操作

--- add 
if _action == "add" then

	if _id == "" then
		optl.sayHtml_ext({code="error",msg="id is nil"})
	else		
		if _value ~= "allow" then _value = "deny" end
		local re = tmpdict:safe_add(_id,_value,_time)
		-- 非重复插入(lru不启用)
		optl.sayHtml_ext({add=re,id=_id,value=_value})
	end
--- del
elseif _action == "del" then

	if _id == "" then
		optl.sayHtml_ext({code="error",msg="id is nil"})
	elseif _id == "all_id" then
	    tmpdict:flush_all()
		local re1 = tmpdict:flush_expired(0)
		optl.sayHtml_ext({flush_expired=re1})
	else
		local re = tmpdict:delete(_id)
		local re1 = tmpdict:flush_expired(0)
		optl.sayHtml_ext({delete=re,flush_expired=re1})
	end
--- set 
elseif _action == "set" then
	if _id == "" then
		optl.sayHtml_ext({code="error",msg="id is nil"})
	else
		local _value = get_argByName("value")
		if _value ~= "allow" then _value = "deny" end
		local re = tmpdict:replace(_id,_value,_time)
		optl.sayHtml_ext({id=_id,value=_value,replace=re})
	end
--- get 
elseif _action == "get" then

	if _id == "count_id" then
		local _tb = tmpdict:get_keys(0)
		optl.sayHtml_ext({count=table.getn(_tb)})
	elseif _id == "all_id" then
		local _tb,tb_all = tmpdict:get_keys(0),{}
		for i,v in ipairs(_tb) do
			tb_all[v] = tmpdict:get(v)
		end
		optl.sayHtml_ext(tb_all)
	elseif _id == "" then
		local _tb = tmpdict:get_keys(1024)
		optl.sayHtml_ext(_tb)
	else
		optl.sayHtml_ext({id=_id,value=tmpdict:get(_id)})
	end

else
	optl.sayHtml_ext({code="error",msg="action is error"})
end

