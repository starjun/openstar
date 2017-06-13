
---- 对token_dict 相关操作  增 删 改 查
--   在app_Mod 中 有添加无状态token操作

local optl = require("optl")

local get_argsByName = optl.get_argsByName
local _action = get_argsByName("action")
local _token = get_argsByName("token")
local token_dict = ngx.shared.token_dict

--- token_list [dict] 操作接口 查询和设置
local _code = "ok"
if _action == "get" then
	
	if _token == "count_token" then
		local _tb = token_dict:get_keys(0)
		optl.sayHtml_ext({code="ok",count_id=table.getn(_tb)})
	elseif _token == "all_token" then
		local _tb,tb_all = token_dict:get_keys(0),{}
		for i,v in ipairs(_tb) do
			tb_all[v] = token_dict:get(v)
		end
		tb_all.code = "ok"
		optl.sayHtml_ext(tb_all)
	elseif _token == "" then
		local _tb = token_dict:get_keys(1024)
		_tb.code = "ok"
		optl.sayHtml_ext(_tb)
	else
		optl.sayHtml_ext({code="ok",token=_token,value=token_dict:get(_token)})
	end

elseif _action == "set" then

	if _token == "" then
		local re = optl.set_token()
		optl.sayHtml_ext({code=_code,msg=re})
	else
		local re = optl.set_token(_token)
		optl.sayHtml_ext({code = _code,msg=re})
	end

else
	optl.sayHtml_ext({code="error",msg="action is error"})
end