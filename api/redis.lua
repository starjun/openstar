
-- local redis_iresty = require "redis_iresty"
local redis = require "resty.redis"
local cjson_safe = require "cjson.safe"
local optl = require("optl")

local host_dict = ngx.shared.host_dict

local config_dict = ngx.shared.config_dict
local config_base = cjson_safe.decode(config_dict:get("base")) or {}

local redis_mod = config_base.redis_Mod or {}

if redis_mod.state == "off" then
    local re = {}
    re.code = "error"
    re.msg = "redis_Mod state is off"
    sayHtml_ext(re)
end

local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end


local _action = get_argByName("action")
local _key = get_argByName("key")
local _value = get_argByName("value")

local red = redis:new()
red:set_timeout(1000) -- 1 sec

local ok, err = red:connect(redis_mod.ip, redis_mod.Port)
if not ok then
    ngx.say("failed to connect: ", err)
    return
end

-- 请注意这里 auth 的调用过程
local count ,err , ok
count, err = red:get_reused_times()
if 0 == count then
    if redis_mod.Password ~= "" then
        ok, err = red:auth(redis_mod.Password)
        if not ok then
            ngx.say("failed to auth: ", err)
            return
        end
    end
elseif err then
    ngx.say("failed to get reused times: ", err)
    return
end

local function push_host_Mod()
    local _tb_host,tb_host_all,tb_host_name = host_dict:get_keys(0),{},{}
    for i,v in ipairs(_tb_host) do
        local from , to = string.find(v, "_HostMod")
        if from == nil then
            local tmp_tb = {}
            tmp_tb[1],tmp_tb[2] = v,host_dict:get(v)
            table.insert(tb_host_name, tmp_tb)
            tb_host_all[v.."_HostMod"] = host_dict:get(v.."_HostMod")
        end
    end
    
    tb_host_all["host_Mod"] = optl.tableTojson(tb_host_name)
    tb_host_name = {}

    red:init_pipeline()
    for i,v in pairs(tb_host_all) do
        table.insert(tb_host_name,i)
        red:set(i,v)
    end

    local results, err = red:commit_pipeline()
    if not results then
        ngx.say("failed to commit the pipelined requests: ", err)
        return
    end

    local res_tb ={}
    for i, res in ipairs(results) do
        if type(res) == "table" then
            if not res[1] then
                ngx.say("failed to run command ", i, ": ", res[2])
            else
                -- process the table value
            end
        else
            -- process the scalar value                
        end
        res_tb[tb_host_name[i]] = res
    end
    optl.sayHtml_ext(res_tb)
end

local function pull_host_Mod()

    local res, err = red:get("host_Mod")
    if not res then
        ngx.say("failed to get ".._key..": ", err)
        return
    end
    if res == ngx.null then
        ngx.say("key not found.")
        return
    end
    local tb_host_Mod = optl.stringTojson(res) or {}

    red:init_pipeline()
    for i,v in ipairs(tb_host_Mod) do
        red:get(v[1].."_HostMod")
    end

    local results, err = red:commit_pipeline()
    if not results then
        ngx.say("failed to commit the pipelined requests: ", err)
        return
    end

    local res_tb ={}
    for i, res in ipairs(results) do
        if type(res) == "table" then
            if not res[1] then
                ngx.say("failed to run command ", i, ": ", res[2])
            else
                -- process the table value
            end
        else
            -- process the scalar value
        end
        res_tb[tb_host_Mod[i][1].."_HostMod"] = res
    end

    host_dict:flush_all()    
    host_dict:flush_expired(0)

    for i,v in ipairs(tb_host_Mod) do
        host_dict:safe_add(v[1],v[2],0)
        host_dict:safe_add(v[1].."_HostMod",res_tb[v[1].."_HostMod"],0)
    end
   
    ngx.say("It is Ok !")

end

if _action == "set" then

	ok, err = red:set(_key, _value)
	if not ok then
	    ngx.say("failed to set ".._key..": ", err)
	    return
	end

	ngx.say("set result: ", ok)

elseif _action == "get" then

	local res, err = red:get(_key)
    if not res then
        ngx.say("failed to get ".._key..": ", err)
        return
    end

    if res == ngx.null then
        ngx.say("key not found.")
        return
    end

    -- if _key == "config_dict" or _key == "count_dict" then
    --     res = cjson_safe.decode(res)---转成json/table
    -- end
    ngx.say(res)

elseif _action == "push" then

    if _key == "config_dict" then  --保存dict中的config_dict到redis        
        local _tb = config_dict:get_keys(0)
        red:init_pipeline()
        for i,v in ipairs(_tb) do
            --tb_all[v] = config_dict:get(v)
            red:set(v, config_dict:get(v))
        end

        local results, err = red:commit_pipeline()
        if not results then
            ngx.say("failed to commit the pipelined requests: ", err)
            return
        end

        local res_tb ={}
        for i, res in ipairs(results) do
            if type(res) == "table" then
                if not res[1] then
                    ngx.say("failed to run command ", i, ": ", res[2])
                else
                    -- process the table value
                end
            else
                -- process the scalar value                
            end
            res_tb[_tb[i]] = res
        end
        optl.sayHtml_ext(res_tb)

    elseif _key == "count_dict" then -- 保存dict中的count_dict到redis

        --- 0 获取远程数据
        local res, err = red:get(_key)
        if not res then
            ngx.say("failed to get "..tostring(_key)..": ", err)
            return
        end
        -- if res == ngx.null then
        --     ngx.say("key not found.")
        --     return
        -- end
        res = cjson_safe.decode(res) or {}

        --- 1 合并本机数据
        local count_dict = ngx.shared.count_dict
        local _tb,tb_all = count_dict:get_keys(0),{}
        for i,v in ipairs(_tb) do
            tb_all[v] = count_dict:get(v)
        end
        
        for k,v in pairs(res) do
            if tb_all[k] == nil then
                tb_all[k] = v
            else
                tb_all[k] = tonumber(v) + tonumber(tb_all[k])
            end
        end

        --- 2 合并后数据 push
        local json_config = cjson_safe.encode(tb_all)
        ok, err = red:set("count_dict", json_config)
        if not ok then
            ngx.say("failed to set count_dict: ", err)
            return
        end

        --- 3 清空本地数据
        local re = count_dict:flush_all()
        local re1 = count_dict:flush_expired(0)

        ngx.say("set count_dict result: ", ok)

    elseif _key == "host_dict" then

        push_host_Mod()

    else
        local _key_v = config_dict:get(_key)
        if _key_v == nil then
            ngx.say("key is nil")
        else
            ok, err = red:set(_key, _key_v)
            if not ok then
                ngx.say("failed to set config_dict: ", err)
                return
            end
            ngx.say("set ".._key.." result: ", ok)
        end
    end

elseif _action == "pull" then --- 从redis拉取配置到dict

    if _key == "config_dict" then
        local _tb = config_dict:get_keys(0)
        red:init_pipeline()
        for i,v in ipairs(_tb) do
            red:get(v)
        end
        local results, err = red:commit_pipeline()
        if not results then
            ngx.say("failed to commit the pipelined requests: ", err)
            return
        end

        local res_tb ={}
        for i, res in ipairs(results) do
            if type(res) == "table" then
                if not res[1] then
                    ngx.say("failed to run command ", i, ": ", res[2])
                else
                    -- process the table value
                end
            else
                -- process the scalar value
            end
            res_tb[i] = res
        end
        for i,v in ipairs(_tb) do
            config_dict:replace(v,res_tb[i])
        end
        ngx.say("It is Ok !")

    elseif _key == "host_dict" then

       pull_host_Mod()

    else
        local res, err = red:get(_key)
        if not res then
            ngx.say("failed to get ".._key..": ", err)
            return
        end
        if res == ngx.null then
            ngx.say("key not found.")
            return
        end
        local _dict_value = config_dict:get(_key)
        local re = config_dict:replace(_key,res)

        optl.sayHtml_ext({re=re,key=_key,redis_value=res,dict_value=_dict_value})
    end

end

-- 连接池大小是100个，并且设置最大的空闲时间是 10 秒
local ok, err = red:set_keepalive(10000, 100)
if not ok then
    ngx.say("failed to set keepalive: ", err)
    return
end