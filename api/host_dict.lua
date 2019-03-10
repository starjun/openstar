
----  对host_dict 进行操作  增 删 改 查
----  host_dict 存放的是基于host的过滤规则列表 和 host过滤开关
--    host_dict 数据源  =  host_Host.json 和 conf_json/host_json/%host%.json 读取到内存的数据

local optl = require("optl")


local get_argsByName
if ngx.var.request_method == "POST" then
    get_argsByName = optl.get_postByName
else
    get_argsByName = optl.get_argsByName
end

local _action = get_argsByName("action")
local _host = get_argsByName("host")
local _id = get_argsByName("id")
local _value = get_argsByName("value")
local _value_type = get_argsByName("value_type")

local host_dict = ngx.shared["host_dict"]


local _code = "ok"
-- 用于host_dict操作接口  对ip列表进行增 删 改 查 操作

if _action == "add" then

    if _id == "state" then --- 添加host_Mod状态
        local host_state = host_dict:get(_host)
        if host_state ~= nil then -- 已存在
            optl.sayHtml_ext({code="error",msg="host is existent"})
        end
        if _value ~= "on" and _value ~= "log" then _value = "off" end
        host_state = _value
        local re = host_dict:safe_add(_host,host_state,0)
        if re ~= true then
            optl.sayHtml_ext({code="error",msg="safe_add error"})
        end
        -- 非重复插入(lru不启用)
        optl.sayHtml_ext({code=_code,id=_id,value=host_state})
    end

    local host_state = host_dict:get(_host)
    if host_state == nil then
        optl.sayHtml_ext({code="error",msg="add host state first"})
    end

    _value = optl.stringTojson(_value)
    if type(_value) ~= "table" then
        optl.sayHtml_ext({code="error",msg="value to json error"})
    end

    local host_mod = optl.stringTojson(host_dict:get(_host.."_HostMod")) or {}

    table.insert(host_mod,_value)
    host_mod = optl.tableTojson(host_mod)
    local re = host_dict:safe_set(_host.."_HostMod",host_mod,0)

    if re ~= true then
        optl.sayHtml_ext({code="error",msg="safe_set error"})
    end
    optl.sayHtml_ext({code=_code,value=_value})

elseif _action == "del" then-- 需要增加删除 所有 host所有
    local host_state = host_dict:get(_host)
    if host_state == nil then
        optl.sayHtml_ext({code="error",msg="host is Non-existent"})
    end

    local host_mod = optl.stringTojson(host_dict:get(_host.."_HostMod")) or {}

    _id = tonumber(_id)
    if _id == nil then
        optl.sayHtml_ext({code="error",msg="id is not number"})
    end

    local rr = table.remove(host_mod,_id)
    if rr == nil then
        optl.sayHtml_ext({code="error",msg="id is Non-existent"})
    else
        local re = host_dict:replace(_host.."_HostMod",optl.tableTojson(host_mod))
        if re ~= true then
            optl.sayHtml_ext({code="error",msg="replace error"})
        end
        optl.sayHtml_ext({code=_code,id=_id,value=rr})
    end

elseif _action == "set" then

    local host_state = host_dict:get(_host)
    if host_state == nil then
        optl.sayHtml_ext({code="error",msg="host is Non-existent"})
    end

    if _id == "state" then
        if _value ~= "on" and _value ~= "log" then _value = "off" end
        local re = host_dict:replace(_host,_value)
        if re ~= true then
            optl.sayHtml_ext({code="error",msg="replace error"})
        end
        optl.sayHtml_ext({code=_code,host=_host,state=_value})
    end

    _id = tonumber(_id)
    if _id == nil then
        optl.sayHtml_ext({code="error",msg="id is not number"})
    end

    _value = optl.stringTojson(_value)
    if type(_value) ~= "table" then
        optl.sayHtml_ext({code="error",msg="value to json error"})
    end

    local host_mod = optl.stringTojson(host_dict:get(_host.."_HostMod")) or {}

    local old_host_id_mod = host_mod[_id]
    if old_host_id_mod == nil then
        optl.sayHtml_ext({code = "error",msg="id is Non-existent"})
    end

    host_mod[_id] = _value
    local re = host_dict:replace(_host.."_HostMod",optl.tableTojson(host_mod))
    if re ~= true then
        optl.sayHtml_ext({code="error",msg="replace error"})
    end
    optl.sayHtml_ext({code=_code,old_value=old_host_id_mod,new_value=_value})

elseif _action == "get" then

    if _host == "all" then
        local _tb,tb_all = host_dict:get_keys(0),{}
        for i,v in ipairs(_tb) do
            tb_all[v] = host_dict:get(v)
        end
        tb_all.code = "ok"
        optl.sayHtml_ext(tb_all)
    elseif _host == "all_host" then
        local _tb,tb_all = host_dict:get_keys(0),{}
        for i,v in ipairs(_tb) do
            local from , to = string.find(v, "_HostMod$")
            if from == nil then
                table.insert(tb_all,v)
            end
        end
        tb_all.code = "ok"
        optl.sayHtml_ext(tb_all)
    else
        local host_state = host_dict:get(_host)
        if host_state == nil then
            optl.sayHtml_ext({code="error",msg="host is Non-existent"})
        end

        if _id == "" then
            local host_mod = host_dict:get(_host.."_HostMod")
            host_mod = optl.stringTojson(host_mod)
            host_mod.state = host_state
            host_mod.code = "ok"
            optl.sayHtml_ext(host_mod)
        elseif _id == "count_id" then
            local host_mod = host_dict:get(_host.."_HostMod")
            host_mod = optl.stringTojson(host_mod)
            local cnt = table.maxn(host_mod)
            optl.sayHtml_ext({code="ok",state=host_state,count=cnt})
        else
            local host_mod = host_dict:get(_host.."_HostMod")
            host_mod = optl.stringTojson(host_mod)
            _id = tonumber(_id)
            if _id == nil then
                optl.sayHtml_ext({code="error",msg="id is not number"})
            end
            optl.sayHtml_ext({code="ok",state=host_state,id = _id,value = host_mod[_id]})
        end
    end

else
    optl.sayHtml_ext({code="error",msg="action is error"})
end