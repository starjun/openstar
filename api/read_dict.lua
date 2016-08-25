

local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end
local _action = get_argByName("action")
local _id = get_argByName("id")
local _dict = get_argByName("dict")

local optl = require("optl")

--- 用于给 limit_ip_dict,count_dict 等查询数据使用

local tmpdict = ngx.shared[_dict]
if tmpdict == nil then 
	optl.sayHtml_ext({code="error",msg="dict is nil"}) 
end

if _action == "get" then
	
	if _id == "count_id" then
		local _tb = tmpdict:get_keys(0)
		optl.sayHtml_ext(table.getn(_tb))
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