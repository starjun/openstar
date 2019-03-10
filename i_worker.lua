local _worker_count = ngx.worker.count()
local _worker_id = ngx.worker.id()

local ngx_shared = ngx.shared
local require = require
local ipairs = ipairs
local stool = require("stool")
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_thread = ngx.thread
local timer_every = ngx.timer.every
local config_dict = ngx_shared.config_dict
local cjson_safe = require "cjson.safe"
local http = require "resty.http"

local handler_all

-- dict 清空过期内存
local function flush_expired_dict()
    local dict_list = {"token_dict","count_dict","config_dict","host_dict","ip_dict","limit_ip_dict"}
    for _,v in ipairs(dict_list) do
        ngx_shared[v]:flush_expired()
    end
end

-- 拉取config_dict配置数据
local function pull_redisConfig()

    local httpc = http.new()
    local _url = "http://127.0.0.1:5460/api/dict_redis?action=pull&key=all_dict"
    local res, err = httpc:request_uri(_url,{
           method = "GET",
           headers = {
             ["Host"] = "127.0.0.1:5460",
           }
         })
    if not res then
        ngx_log(ngx_ERR, "failed to pull_redisConfig request: ", err)
        return
    else
        return true
    end
end

-- 推送config_dict、host_dict、count_dict到redis
local function push_Master()

    local httpc = http.new()
    local _url = "http://127.0.0.1:5460/api/dict_redis?action=push&key=all_dict&slave=yes"
    local res, err = httpc:request_uri(_url,{
           method = "GET",
           headers = {
             ["Host"] = "127.0.0.1:5460",
           }
         })
    if not res then
        ngx_log(ngx_ERR, "failed to push_Master request: ", err)
        return
    else
        return true
    end
end

-- 推送count_dict统计、计数等
local function push_count_dict()

    local httpc = http.new()
    local _url = "http://127.0.0.1:5460/api/dict_redis?action=push&key=count_dict"
    local res, err = httpc:request_uri(_url,{
           method = "GET",
           headers = {
             ["Host"] = "127.0.0.1:5460",
           }
         })
    if not res then
        ngx_log(ngx_ERR, "failed to push_count_dict request: ", err)
        return
    else
        return true
    end
end

-- 保存config_dict、host_dict到本机文件
local function save_configFile(_debug)

    local httpc = http.new()
    local _url = "http://127.0.0.1:5460/api/config?action=save&mod=all_Mod&debug=".._debug
    local res, err = httpc:request_uri(_url,{
           method = "GET",
           headers = {
             ["Host"] = "127.0.0.1:5460",
           }
         })
    if not res then
        ngx_log(ngx_ERR, "failed to save_configFile request: ", err)
        return
    else
        return true
    end
end

-- worker_id zero 执行定时操作
local function handler_zero()
    local config = cjson_safe.decode(config_dict:get("config")) or {}
    local config_base = config.base or {}
    -- 如果 auto Sync 开启 就定时从redis 拉取配置并推送一些计数
    if config_base.autoSync.state == "Master" then
        push_Master()
    elseif config_base.autoSync.state == "Slave" then
        if pull_redisConfig() then
            local _debug = "no"
            if config_base.debug_Mod then
                _debug = "yes"
            end
            save_configFile(_debug)
        end
        --推送count_dict到redis
        push_count_dict()
    else
        -- nothing todo
    end

    --清空过期内存
    ngx_thread.spawn(flush_expired_dict)
end

handler_all = function ()
    local optl = require("optl")
    local dict_config_version = config_dict:get("config_version")
    local optl_config_version = optl.config_version
    if dict_config_version ~= optl_config_version then
        local config = cjson_safe.decode(config_dict:get("config"))
        if config and not stool.table_compare(config,optl.config) then
            -- 后续 对 整个规则进行 合法性判断
            optl.config = config
        end
        optl.config_version = dict_config_version
    end
end


if _worker_id == 0 then
    local config = cjson_safe.decode(config_dict:get("config")) or {}
    local config_base = config.base or {}
    local timeAt = config_base.autoSync.timeAt or 5
    timer_every(timeAt,handler_zero)
end
timer_every(1,handler_all)
