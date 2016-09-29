
---- 对token_dict 相关操作  增 删 改 查
--   在app_Mod 中 有添加无状态token操作

local optl = require("optl")

local get_argsByName = optl.get_argsByName
local _action = get_argsByName("action")
local _token = get_argsByName("token")
local tmpdict = ngx.shared.token_dict

--- token_list [dict] 操作接口 查询和设置
local _code = "ok"
if _action == "get" then
	
	if _token == "count_token" then
		local _tb = tmpdict:get_keys(0)
		optl.sayHtml_ext({count_id=table.getn(_tb)})
	elseif _token == "all_token" then
		local _tb,tb_all = tmpdict:get_keys(0),{}
		for i,v in ipairs(_tb) do
			tb_all[v] = tmpdict:get(v)
		end
		optl.sayHtml_ext(tb_all)
	elseif _token == "" then
		local _tb = tmpdict:get_keys(1024)
		optl.sayHtml_ext(_tb)
	else
		optl.sayHtml_ext({token=_token,value=tmpdict:get(_token)})
	end

elseif _action == "set" then

	if _token == "" then
		local re,_tk = optl.set_token()
		if re ~= true then
			_code = "error"
		end
		optl.sayHtml_ext({code=_code,token=_tk})
	else
		local re,_tk = optl.set_token(_token)
		if re ~= true then
			_code = "error"
		end
		optl.sayHtml_ext({code = _code,token=tmpdict:get(_token)})
	end

else
	optl.sayHtml_ext({code="error",msg="action is error"})
end