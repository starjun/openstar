
----  对redis 的操作
--    连接的redis配置是在base.json 中
--    主要使用的是 从redis 拉取数据到本机内存  / 推送本机配置到redis (内存中的配置)
--    配置包括 config_dic / host_dict / count_dict / 部分ip_dict 数据
--    ip_dict 中暂时仅包含永久数据 time=0 动态生成在 暂时没有同步到redis

--    redis DB 0 存放 config_dict 、 host_dict 、 count_dict
--    config_dict 的key = config
--    redis 对应：base realIpFrom_Mod deny_Msg uri_Mod header_Mod
--                useragent_Mod cookie_Mod args_Mod post_Mod network_Mod 
--                replace_Mod host_method_Mod rewrite_Mod app_Mod referer_Mod
--    host_dict 的  key = host_Mod %host%_HostMod

--    redis DB 1 存放 ip_dict
--    ip_dict 的 key = %ip% ,%host%-%ip%

--    redis DB 2 存放 count_dict
--    count_dict 的 key = global request count ,global request get|post|head等, 拦截计数，请求计数等

-- local redis_iresty = require "redis_iresty"
local redis = require "resty.redis"
local cjson_safe = require "cjson.safe"
local optl = require("optl")

local host_dict = ngx.shared.host_dict
local count_dict = ngx.shared.count_dict
local ip_dict = ngx.shared.ip_dict
local config_dict = ngx.shared.config_dict

local config = cjson_safe.decode(config_dict:get("config")) or {}
local config_base = config.base or {}
local redis_mod = config_base.redis_Mod or {}


local get_argsByName = optl.get_argsByName
local sayHtml_ext = optl.sayHtml_ext

-- 主配置中查看redis是否 启用
if redis_mod.state == "off" then
    sayHtml_ext({code="error",msg="redis_Mod state is off"})
end

local _action = get_argsByName("action")
local _key = get_argsByName("key")
local _value = get_argsByName("value")
local _db = tonumber(get_argsByName("db")) or 0
local _slave = get_argsByName("slave")

local red = redis:new()
red:set_timeout(2000) -- 2 sec

local ok, err = red:connect(redis_mod.ip, redis_mod.Port)
if not ok then
    local _msg = "failed to connect: "..tostring(err)
    sayHtml_ext({code="error",msg=_msg})
    --ngx.say("failed to connect: ", err)
    return
end

-- 请注意这里 auth 的调用过程
local count, err = red:get_reused_times()
if 0 == count then
    if redis_mod.Password ~= "" then
        local ok, err = red:auth(redis_mod.Password)
        if not ok then
            local _msg = "failed to auth: "..tostring(err)
            sayHtml_ext({code="error",msg=_msg})
            --ngx.say("failed to auth: ", err)
            return
        end
    end
elseif err then
    local _msg = "failed to get reused times: "..tostring(err)
    sayHtml_ext({code="error",msg=_msg})
    --ngx.say("failed to get reused times: ", err)
    return
end

-- 推送 config 的 config 到redis DB 0
-- isexit == true 需要 ngx.exit()
local function push_config(_isexit)

    -- 切换ip_dict 数据库 DB 0     
    local ok, err = red:select(0)
    if not ok then
        local _msg = "failed to select : "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to select : ", err)
        return
    end

    red:init_pipeline()
    local _tb = {}
    if _slave == "yes" then
        config.base.autoSync.state = "Slave"
    end
    for k,v in pairs(config) do
        red:set(k, cjson_safe.encode(v))
        table.insert(_tb,k)
    end

    local results, err = red:commit_pipeline()
    if not results then
        local _msg = "failed to commit the pipelined requests: "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to commit the pipelined requests: ", err)
        return
    end

    local res_tb ={}
    local _code = "ok"
    for i, res in ipairs(results) do
        if res ~= "OK" then
            _code = "error"
        end
        res_tb[_tb[i]] = res
    end

    -- 执行结果都在res_tb中
    if _isexit then
        sayHtml_ext({code = _code,msg=res_tb})
    else
        return
    end
end

-- 从 redis DB 0 拉取各个 Mod 整合到config中
-- isexit == true 需要 ngx.exit()
local function pull_config(_isexit)
    -- 切换ip_dict 数据库 DB 0
    local ok, err = red:select(0)
    if not ok then
        local _msg = "failed to select : "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to select : ", err)
        return
    end

    local _tb = {}
    red:init_pipeline()
    for k,v in pairs(config) do
        red:get(k)
        table.insert(_tb,k)
    end
    local results, err = red:commit_pipeline()
    if not results then
        local _msg = "failed to commit the pipelined requests: "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to commit the pipelined requests: ", err)
        return
    end

    local _msg ={}
    for i, res in ipairs(results) do
        local tb_res = cjson_safe.decode(res)
        if tb_res ~= nil then
            config[_tb[i]] = tb_res
            _msg[_tb[i]] = "pull ok"
        else
            _msg[_tb[i]] = "pull error"
        end
    end
    
    local _code = "ok"
    local re = config_dict:replace("config",cjson_safe.encode(config))
    if re ~= true then
       _code = "error"
    else
        config_dict:incr("config_version",1)
    end  

    -- 执行结果都在res_tb中
    if _isexit then
        sayHtml_ext({code = _code,msg=_msg})
    else
        return
    end
end

-- 将 host_Mod 全部推送到redis DB 0
-- isexit == true 需要 ngx.exit()
local function push_host_Mod(_isexit)
    -- 获取host_dict中所有key
    -- tb_host_name 所有host name
    -- tb_host_all  所有host 对应 host_HostMod 和 host == > host_Mod

    -- 切换数据库 DB 0
    local ok, err = red:select(0)
    if not ok then
        local _msg = "failed to select : "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to select : ", err)
        return
    end

    local _tb_host,tb_host_all,tb_host_name = host_dict:get_keys(0),{},{}

    for i,v in ipairs(_tb_host) do
        local from , to = string.find(v, "_HostMod$")
        if from == nil then
            local tmp_tb = {}
            tmp_tb[1],tmp_tb[2] = v,host_dict:get(v)
            table.insert(tb_host_name, tmp_tb)
            tb_host_all[v.."_HostMod"] = host_dict:get(v.."_HostMod")
        end
    end    
    tb_host_all["host_Mod"] = optl.tableTojson(tb_host_name)

    tb_host_name = {}
    -- 批量执行redis命令 set，结果集，同执行循序一致
    red:init_pipeline()
    for k,v in pairs(tb_host_all) do
        table.insert(tb_host_name,k)
        red:set(k,v)
    end

    local results, err = red:commit_pipeline()
    if not results then
        local _msg = "failed to commit the pipelined requests: "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to commit the pipelined requests: ", err)
        return
    end

    local _msg ={}
    local _code = "ok"
    for i, res in ipairs(results) do
        if res ~= "OK" then
            _code = "error"
        end
        _msg[tb_host_name[i]] = res
    end

    -- 执行结果都在res_tb中
    if _isexit then
        sayHtml_ext({code = _code,msg=_msg})
    else
        return
    end
end

-- 从redis DB 0 拉取hostMod规则
-- isexit == true 需要 ngx.exit()
local function pull_host_Mod(_isexit)

    -- 切换数据库 DB 0
    local ok, err = red:select(0)
    if not ok then
        local _msg = "failed to select : "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to select : ", err)
        return
    end

    -- 获取所有host == > host_Mod
    local res, err = red:get("host_Mod")
    if not res then
        local _msg = "failed to get key : "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to get ".._key..": ", err)
        return
    end

    local tb_host_Mod = optl.stringTojson(res) or {}

    -- 取出 host_Mod 中所有host 对应 _HostMod 数据
    -- redis 批量执行 get
    red:init_pipeline()
    for i,v in ipairs(tb_host_Mod) do
        red:get(v[1].."_HostMod")
    end

    local results, err = red:commit_pipeline()
    if not results then
        local _msg = "failed to commit the pipelined requests: "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to commit the pipelined requests: ", err)
        return
    end

    local res_tb ={}
    for i, res in ipairs(results) do
        res_tb[tb_host_Mod[i][1].."_HostMod"] = res
    end

    local _msg = {}
    local _code = "ok"
    -- ? 清空本地 host_dict
    host_dict:flush_all()    
    _msg.flush_expired = host_dict:flush_expired(0)

    for i,v in ipairs(tb_host_Mod) do
        local  re = host_dict:safe_add(v[1],v[2],0)
        _msg[v[1]] = re
        if re ~= true then
            _code = "error"
        end
        local re = host_dict:safe_add(v[1].."_HostMod",res_tb[v[1].."_HostMod"],0)
        if re ~= true then
            _code = "error"
        end
        _msg[v[1].."_HostMod"] = re
    end
    
    if _isexit then
        sayHtml_ext({code = _code,msg=_msg})
    else
        return
    end
end

-- 仅推送init阶段 时增加的 永久IP名单列表
-- isexit == true 需要 ngx.exit()
local function push_ip_Mod(_isexit)

    -- 获取所有永久状态的 ip 列表
    local _tb_ip_name,tb_ip_all = ip_dict:get_keys(0),{}
    for i,v in ipairs(_tb_ip_name) do
        local ip_value = ip_dict:get(v)
        --- init 中，永久ip只有这3个value
        if ip_value == "allow" or ip_value == "deny" or ip_value == "log" then            
            tb_ip_all[v] = ip_value
        end        
    end
    
    -- 切换ip_dict 数据库 1 
    local ok, err = red:select(1)
    if not ok then
        local _msg = "failed to select : "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        return
    end

    -- 批量执行 redis set 命令
    local _tb = {}
    red:init_pipeline()
    for k,v in pairs(tb_ip_all) do
        table.insert(_tb,k)
        red:set(k,v)
    end
    local results, err = red:commit_pipeline()
    if not results then
        local _msg = "failed to commit the pipelined requests: "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to commit the pipelined requests: ", err)
        return
    end

    local res_tb ={}
    local _code = "ok"
    for i, res in ipairs(results) do
        if res ~= "OK" then
           _code = "error"
        end
        res_tb[_tb[i]] = res
    end
    
    if _isexit then
        sayHtml_ext({code = _code ,msg = res_tb})
    else
        return
    end
end

-- 从redis DB 1 拉取ip_Mod
-- isexit == true 需要 ngx.exit()
local function pull_ip_Mod(_isexit)

    -- 切换ip_dict 数据库 DB 1
    local ok, err = red:select(1)
    if not ok then
        local _msg = "failed to select : "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to select : ", err)
        return
    end

    -- 获取所有keys
    ok, err = red:keys("*")
    if not ok then
        local _msg = "failed to keys : "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to keys : ", err)
        return
    end

    red:init_pipeline()

    --- 先取值
    for i,v in ipairs(ok) do
        red:get(v)
    end
    local results, err = red:commit_pipeline()
    if not results then
        local _msg = "failed to commit the pipelined (get key) requests: "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to commit the pipelined (get key) requests: ", err)
        return
    end
    local res_tb ={}

    for i, res in ipairs(results) do
        res_tb[ok[i]] = {value=res,time=0}
    end

    red:init_pipeline()

    --- 再取 ttl
    for i,v in ipairs(ok) do
        red:ttl(v)
    end
    local results, err = red:commit_pipeline()
    if not results then
        local _msg = "failed to commit the pipelined requests: "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to commit the pipelined requests: ", err)
        return
    end

    for i, res in ipairs(results) do
        res_tb[ok[i]].time = res
    end
    
    -- 将redis中的数据添加
    local _msg = {}
    local _code = "ok"
    for k,v in pairs(res_tb) do        
        if v.time ~= 0 then
            if v.time == -1 then v.time = 0 end
            local re = ip_dict:safe_set(k,v.value,v.time)
            if re ~= true then
                _code = "error"
            end
            _msg[k] = re
        end
    end
    
    if _isexit then
        sayHtml_ext({code = _code,msg=_msg})
    else
        return
    end
end

-- 推送 count_dict 计数到 redis DB 2
-- isexit == true 需要 ngx.exit()
local function push_count_dict(_isexit)
    red:init_pipeline()
    local _code = "ok"
    local _msg = "push_count_dict ok"
    local error_tb = {}

    local _tb = count_dict:get_keys(0)
    if #_tb > 0 then
        for i,v in ipairs(_tb) do
            local number_v = tonumber(count_dict:get(v)) or 0
            local redis_cmd = string.format("redis.call('select',2) local cnt = tonumber(redis.call('get','%s') or 0) return redis.call('set','%s',cnt+%s)",v,v,number_v)
            red:eval(redis_cmd,0)
        end

        local results, err = red:commit_pipeline()
        if not results then
            local _msg = "failed to commit the pipelined (push_count_dict) requests: "..tostring(err)
            sayHtml_ext({code="error",msg=_msg})
            return
        end

        for i, v in ipairs(results) do
            if v == "OK" then
                count_dict:delete(_tb[i])
            else
                _code = "error"
                local err_tmp ={}
                err_tmp[_tb[i]]=v
                table.insert(error_tb,err_tmp)
            end
        end
    end

    if _isexit then
        if _code == "error" then            
            _msg = error_tb
        end
        sayHtml_ext({code=_code,msg=_msg})
    else
        return
    end
end

if _action == "set" then
    -- 测试写redis 谨慎使用
    -- 切换ip_dict 数据库 DB 参数 db
    local ok, err = red:select(_db)
    if not ok then
        local _msg = "failed to select : "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to select : ", err)
        return
    end

	local ok, err = red:set(_key, _value)
	if not ok then
        local _msg = "failed to set key : "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
	    --ngx.say("failed to set ".._key..": ", err)
	    return
	end

	--ngx.say("set result: ", ok)
    sayHtml_ext({code="ok",msg=ok})

-- elseif _action == "ttl" then

--     if _key == "" then _key = "ttl_test" end
--     ok, err = red:ttl(_key)
--     if not ok then
--         return ngx.say("failed to ttl :",err)
--     end

--     ngx.say(ok)

-- elseif _action == "select" then
--     ok, err = red:select(1)
--     if not ok then
--         ngx.say("failed to select : ", err)
--         return
--     end
--     ok, err = red:set("fuck", "fuck you")

--     if not ok then
--         ngx.say("failed to set ".._key..": ", err)
--         return
--     end

--     ngx.say("set result: ", ok)

elseif _action == "get" then
    -- 测试读redis
    -- 切换ip_dict 数据库 DB 参数 db
    local ok, err = red:select(_db)
    if not ok then
        local _msg = "failed to select : "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to select : ", err)
        return
    end

	local res, err = red:get(_key)
    if not res then
        local _msg = "failed to get key: "..tostring(err)
        sayHtml_ext({code="error",msg=_msg})
        --ngx.say("failed to get ".._key..": ", err)
        return
    end

    --ngx.say(res)
    sayHtml_ext({code="ok",key=_key,value=res})

--推送数据到redis
elseif _action == "push" then

    if _key == "config_dict" then  --保存dict中的config_dict到redis

        push_config(true)

    elseif _key == "count_dict" then -- 保存dict中的count_dict到redis

        push_count_dict(true)

    elseif _key == "host_dict" then

        push_host_Mod(true)

    elseif _key == "ip_dict" then
       
        push_ip_Mod(true)

    elseif _key == "all_dict" then

        push_config()
        push_ip_Mod()
        push_host_Mod()
        push_count_dict(true)

    else
        -- 切换ip_dict 数据库 DB 0
        local ok, err = red:select(0)
        if not ok then
            local _msg = "failed to select : "..tostring(err)
            sayHtml_ext({code="error",msg=_msg})
            --ngx.say("failed to select : ", err)
            return
        end

        local _key_v = config[_key]
        if _key_v == nil then
            local _msg = "config[".._key.."] is nil"
            sayHtml_ext({code="error",msg=_msg})
            --ngx.say("key is nil")
        else
            ok, err = red:set(_key, cjson_safe.encode(_key_v))
            if not ok then
                local _msg = "failed to set config_dict: "..tostring(err)
                sayHtml_ext({code="error",msg=_msg})
                --ngx.say("failed to set config_dict: ", err)
                return
            end
            --ngx.say("set ".._key.." result: ", ok)
            sayHtml_ext({code="ok",msg="config[".._key.."] push ok"})
        end

    end

--- 从redis拉取配置到dict
elseif _action == "pull" then

    if _key == "config_dict" then

        pull_config(true)

    elseif _key == "host_dict" then

        pull_host_Mod(true)

    elseif _key == "ip_dict" then

        pull_ip_Mod(true)

    elseif _key == "all_dict" then

        pull_host_Mod()
        pull_config()
        pull_ip_Mod(true)

    else

        local res, err = red:get(_key)
        if not res then
            local _msg = "failed to get "..tostring(err)
            sayHtml_ext({code="error",msg=_msg})
            --ngx.say("failed to get ".._key..": ", err)
            return
        end
        local _msg = {}
        local _code = "ok"
        _msg.key = _key
        _msg.old_value = config[_key]
        _msg.new_value = cjson_safe.decode(res)
        config[_key] = _msg.new_value
        local re = config_dict:replace("config",cjson_safe.encode(config))
        if re ~= true then
            _code = "error"
        else
            config_dict:incr("config_version",1)
        end
        -- 执行结果 在 code 中
        sayHtml_ext({code = _code,msg=_msg})

    end

end

-- 连接池大小是100个，并且设置最大的空闲时间是 10 秒
local ok, err = red:set_keepalive(10000, 100)
if not ok then
    local _msg = "failed to set keepalive: "..tostring(err)
    sayHtml_ext({code="error",msg=_msg})
    --ngx.say("failed to set keepalive: ", err)
    return
end