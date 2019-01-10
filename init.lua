
local config = {}
local cjson_safe = require "cjson.safe"
local ngx_shared = ngx.shared
local io_open = io.open
local table_insert = table.insert
local string_gsub = string.gsub
local ipairs = ipairs

--- base.json 文件绝对路径 [需要自行根据自己服务器情况设置]
local base_json = "/opt/openresty/openstar/conf_json/base.json"

--- 将全局配置参数存放到共享内存（*_dict）中
local config_dict = ngx_shared.config_dict
local host_dict = ngx_shared.host_dict
local ip_dict = ngx_shared.ip_dict

--- 读取文件（全部读取/按行读取）
--- loadjson()调用
local function readfile(_filepath,_ty)
    local fd = io_open(_filepath,"r")
    if not fd then return end
    if not _ty then
        --- 全部内容读取
        local str = fd:read("*a")
        fd:close()
        return str
    else
        local line_s = {}
        for line in fd:lines() do
            table_insert(line_s, line)
        end
        fd:close()
        return line_s
    end
end

--- 载入JSON文件
--- loadConfig()调用
local function loadjson(_path_name)
    local x = readfile(_path_name)
    local json = cjson_safe.decode(x) or {}
    return json
end

--- 载入config.json全局基础配置
--- 唯一一个全局函数
function loadConfig()

    config.base = loadjson(base_json)
    local _basedir = config.base.jsonPath or "/opt/openresty/openstar/conf_json/"

    -- STEP 0
    config.realIpFrom_Mod = loadjson(_basedir.."realIpFrom_Mod.json")

    -- STEP 1
    --- 将ip_mod放入 ip_dict 中
    local allowIpList = readfile(_basedir.."ip/allow.ip",true)
    local denyIpList = readfile(_basedir.."ip/deny.ip",true)
    local logIpList = readfile(_basedir.."ip/log.ip",true)
    for _,v in ipairs(allowIpList) do
        v = string_gsub(v,"\r\n","")
        v = string_gsub(v,"\r","")
        v = string_gsub(v,"\n","")
        ip_dict:safe_set(v,"allow",0)
    end
    for _,v in ipairs(denyIpList) do
        v = string_gsub(v,"\r\n","")
        v = string_gsub(v,"\r","")
        v = string_gsub(v,"\n","")
        ip_dict:safe_set(v,"deny",0)
    end
    for _,v in ipairs(logIpList) do
        v = string_gsub(v,"\r\n","")
        v = string_gsub(v,"\r","")
        v = string_gsub(v,"\n","")
        ip_dict:safe_set(v,"log",0)
    end

    -- STEP 2
    config.host_method_Mod = loadjson(_basedir.."host_method_Mod.json")

    -- STEP 3
    config.rewrite_Mod = loadjson(_basedir.."rewrite_Mod.json")

    -- STEP 4
    --- 读取host规则json 到host_dict
    local host_tb = loadjson(_basedir.."host_json/host_Mod.json")
    for _,v in ipairs(host_tb) do
        local host,state = v[1],v[2] or "off"
        if host ~= nil then
            host_dict:safe_set(host,state,0)
            local tmp = loadjson(_basedir.."host_json/"..host..".json")
            tmp = cjson_safe.encode(tmp)
            host_dict:safe_set(host.."_HostMod",tmp,0)
        end
    end

    -- STEP 5 - 14
    config.app_Mod = loadjson(_basedir.."app_Mod.json")
    config.referer_Mod = loadjson(_basedir.."referer_Mod.json")
    config.uri_Mod = loadjson(_basedir.."uri_Mod.json")
    config.header_Mod = loadjson(_basedir.."header_Mod.json")
    config.useragent_Mod = loadjson(_basedir.."useragent_Mod.json")
    config.cookie_Mod = loadjson(_basedir.."cookie_Mod.json")
    config.args_Mod = loadjson(_basedir.."args_Mod.json")
    config.post_Mod = loadjson(_basedir.."post_Mod.json")
    config.network_Mod = loadjson(_basedir.."network_Mod.json")
    config.replace_Mod = loadjson(_basedir.."replace_Mod.json")

    -- denyMsg list
    config.denyMsg = loadjson(_basedir.."denyMsg.json")

    config_dict:safe_set("config",cjson_safe.encode(config),0)
    config_dict:safe_set("config_version",0,0)

end

loadConfig()
G_filehandler = io_open(config.base.logPath..(config.base.log_conf.filename or "waf.log"),"a+")