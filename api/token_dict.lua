

local optl = require("optl")

local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end
local _action = get_argByName("action")
local _id = get_argByName("id")
local _token = get_argByName("token")
local tmpdict = ngx.shared.token_dict

--- token_list [dict] 操作接口 查询和设置

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
		optl.sayHtml_ext(tmpdict:get(_id))
	end

elseif _action == "set" then

	if _token == "" then
		local re = optl.set_token()
		optl.sayHtml_ext({_token=re})
	else
		local re = optl.set_token(_token)
		optl.sayHtml_ext({_token = re})
	end

else
	optl.sayHtml_ext({code="error",msg="action is error"})
end