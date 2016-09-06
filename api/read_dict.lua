
local optl = require("optl")

local get_argsByName = optl.get_argsByName

local _action = get_argsByName("action")
local _id = get_argsByName("id")
local _dict = get_argsByName("dict")


--- 用于给 limit_ip_dict,count_dict 等查询数据使用

local tmpdict = ngx.shared[_dict]
if tmpdict == nil then 
	optl.sayHtml_ext({code="error",msg="dict is nil"}) 
end

if _action == "get" then
	
	if _id == "count_id" then
		local _tb = tmpdict:get_keys(0)
		optl.sayHtml_ext({count_id=table.getn(_tb)})
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
		--ngx.say(tmpdict:get(_id))
	end

else
	optl.sayHtml_ext({code="error",msg="action is error"})
end