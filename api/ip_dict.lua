
---- 对ip_dict 操作 增 删 改 查
---- ip_dict 是全局ip 黑白名单 和 基于host的ip黑白名单 内存存放处
-- 全局 ip 添加  ip=%ip%  不支持cidr
-- 基于host 的ip 规则添加  %host%_ip 不支持cidr


local optl = require("optl")

local get_argsByName
if ngx.var.request_method == "POST" then
    get_argsByName = optl.get_postByName
else
    get_argsByName = optl.get_argsByName
end

local _action = get_argsByName("action")
local _ip = get_argsByName("ip")
local _value = get_argsByName("value")
if _value ~= "allow" and _value ~= "log" then _value = "deny" end
local _time = tonumber( get_argsByName("time")) or 0

local ip_dict = ngx.shared["ip_dict"]
local config_dict = ngx.shared.config_dict
local config = optl.stringTojson(config_dict:get("config"))
local config_base = config.base or {}

-- 用于ip_dict操作接口  对ip列表进行增 删 改 查 操作

local _code = "ok"
--- add
if _action == "add" then
    if _ip == "" then
        optl.sayHtml_ext({code="error",msg="ip is nil"})
    else
        local re = ip_dict:safe_add(_ip,_value,_time)
        -- 非重复插入(lru不启用)
        if not re then
            optl.sayHtml_ext({code="error",msg="ip safe_add error"})
        else
            optl.sayHtml_ext({code=_code,ip=_ip,value=_value})
        end
    end
--- del
elseif _action == "del" then
    if _ip == "" then
        optl.sayHtml_ext({code="error",msg="ip is nil"})
    elseif _ip == "all_ip" then
        ip_dict:flush_all()
        -- ip_dict:flush_expired(0)
        optl.sayHtml_ext({code=_code,ip="all_ip"})
    else
        local re = ip_dict:delete(_ip)
        -- ip_dict:flush_expired(0)
        if not re then
            optl.sayHtml_ext({code="error",msg="ip delete error"})
        else
            optl.sayHtml_ext({code=_code,ip=_ip})
        end
    end
--- set
elseif _action == "set" then
    if _ip == "" then
        optl.sayHtml_ext({code="error",msg="ip is nil"})
    else
        local re = ip_dict:replace(_ip,_value,_time)
        if re ~= true then
            optl.sayHtml_ext({code="error",msg="ip replace error"})
        else
            optl.sayHtml_ext({code=_code,ip=_ip,value=_value})
        end
    end
--- get
elseif _action == "get" then
    if _ip == "count_ip" then
        local _tb = ip_dict:get_keys(0)
        optl.sayHtml_ext({code="ok",count=#_tb})
    elseif _ip == "all_ip" then
        local _tb,tb_all = ip_dict:get_keys(0),{}
        for i,v in ipairs(_tb) do
            tb_all[v] = ip_dict:get(v)
        end
        tb_all.state = config_base["ip_Mod"]
        tb_all.code = "ok"
        optl.sayHtml_ext(tb_all)
    elseif _ip == "" then
        local _tb = ip_dict:get_keys(1024)
        _tb.code = "ok"
        _tb.state = config_base["ip_Mod"]
        optl.sayHtml_ext(_tb)
    else
        optl.sayHtml_ext({code="ok",ip=_ip,value=ip_dict:get(_ip)})
    end
else
    optl.sayHtml_ext({code="error",msg="action is error"})
end

