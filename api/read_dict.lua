
---- 对所有dict  查询操作  config_dict  host_dict  ip_dict  count_dict token_dict limit_ip_dict
-- 仅支持查询


local optl = require("optl")

local get_argsByName
if ngx.var.request_method == "POST" then
    get_argsByName = optl.get_postByName
else
    get_argsByName = optl.get_argsByName
end

local _action = get_argsByName("action")
local _dict = get_argsByName("dict")
local _id = get_argsByName("id")


--- 用于给 limit_ip_dict,count_dict 等查询数据使用

local tmpdict = ngx.shared[_dict]
if not tmpdict then
    optl.sayHtml_ext({code="error",msg="dict is nil"})
end

if _action == "get" then
    if _id == "count_id" then
        local _tb = tmpdict:get_keys(0)
        optl.sayHtml_ext({code="ok",count_id=#_tb})
    elseif _id == "all_id" then
        local _tb,tb_all = tmpdict:get_keys(0),{}
        for i,v in ipairs(_tb) do
            tb_all[v] = tmpdict:get(v)
        end
        tb_all.code = "ok"
        optl.sayHtml_ext(tb_all)
    elseif _id == "" then
        local _tb = tmpdict:get_keys(0)
        _tb.code = "ok"
        optl.sayHtml_ext(_tb)
    else
        optl.sayHtml_ext({code="ok",id=_id,value=tmpdict:get(_id)})
    end
else
    optl.sayHtml_ext({code="error",msg="action is error"})
end