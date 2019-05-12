-----  access_all by zj  -----
local optl = require("optl")
local ngx_var = ngx.var
local ngx_ctx = ngx.ctx
local ngx_unescape_uri = ngx.unescape_uri
local config = optl.config
local config_base = config.base or {}
local action_tag = ""

local string_find = string.find
local string_upper = string.upper
local type = type
local tostring = tostring
local table_insert = table.insert
local ipairs = ipairs
local pairs = pairs
local loadstring = loadstring
local tonumber = tonumber
local math_min = math.min

local limit_ip_dict = ngx.shared.limit_ip_dict
local ip_dict = ngx.shared.ip_dict
local host_dict = ngx.shared.host_dict



-- 经测试可直接用request_id,无重复产生 openresty >= 1.11.0.0
local next_ctx = {request_guid = ngx_var.request_id}
ngx_ctx.next_ctx = next_ctx

-- 获取所有参数的内容
    local remoteIp = ngx_var.remote_addr
    local host = ngx_unescape_uri(ngx_var.http_host)
    local ip = remoteIp
    local method = ngx_var.request_method
    local request_uri = ngx_unescape_uri(ngx_var.request_uri)
    local uri = ngx_unescape_uri(ngx_var.uri)
    local useragent = ngx_unescape_uri(ngx_var.http_user_agent)
    local referer = ngx_unescape_uri(ngx_var.http_referer)
    local cookie = ngx_unescape_uri(ngx_var.http_cookie)
    local query_string = ngx_unescape_uri(ngx_var.query_string)

    local headers = ngx.req.get_headers()
    local headers_data
    -- local function tmp_pcall()
    --     headers_data = ngx_unescape_uri(ngx.req.raw_header(false))
    -- end
    -- pcall(tmp_pcall)
    if ngx_var.server_protocol ~= "HTTP/2.0" then
        headers_data = ngx_unescape_uri(ngx.req.raw_header(false))
    end
    local http_content_type = ngx_unescape_uri(ngx_var.http_content_type)

    local args = ngx.req.get_uri_args()
    local args_data = optl.get_table(args)

    local posts = {}
    local posts_data = ""
    local posts_all
    if method == "POST" and http_content_type then
        -- multipart/form-data; boundary=----WebKitForm...
        local from,to = string_find(http_content_type,"x-www-form-urlencoded",1,true)
        if from then
            posts = ngx.req.get_post_args()
            posts_data = optl.get_table(posts)
        end
    end

local base_msg = {}
    -- string 类型http参数
    base_msg.remoteIp = remoteIp
    base_msg.host = host
    base_msg.ip = ip
    base_msg.method = method
    base_msg.request_uri = request_uri
    base_msg.uri = uri
    base_msg.useragent = useragent
    base_msg.referer = referer
    base_msg.cookie = cookie
    base_msg.query_string = query_string

    -- table 类型参数
    base_msg.headers = headers
    base_msg.args = args
    base_msg.posts = posts

    -- table_str
    base_msg.headers_data = headers_data
    base_msg.args_data = args_data
    base_msg.posts_data = posts_data

next_ctx.base_msg = base_msg


local host_Mod_state = host_dict:get(host)

--- 2016年8月4日 增加全局Mod开关
--  增加基于host的过滤模块开关判断
if config_base.Mod_state == "off" or host_Mod_state == "off" then
    return
end

--- 判断config_dict中模块开关是否开启
local function config_is_on(_config_arg)
    if _config_arg == "args_Mod" then
        return config_base[_config_arg]["state"] == "on"
    elseif _config_arg == "post_Mod" then
        return config_base[_config_arg]["state"] == "on"
    else
        return config_base[_config_arg] == "on"
    end
end

--- 取config_dict中的json数据
local function getDict_Config(_Config_jsonName)
    local re = config[_Config_jsonName] or {}
    return re
    -- return (config[_Config_jsonName] or {})
end

--- remath_ext 是 remath_Invert(str,re_str,options,true) 的扩展
local function remath_ext(str,_modRule)
    if type(_modRule) ~= "table" then return false end
    if _modRule[2] == "rein_list" then
        return optl.remath_Invert(string_upper(str),_modRule[1],_modRule[2],_modRule[3])
    else
        return optl.remath_Invert(str,_modRule[1],_modRule[2],_modRule[3])
    end
end

--- 访问频率检查 并且计数
-- _tb_network 频率规则  _uid 唯一标识
-- true:触发 频率限制  false:未触发 计数++
local function network_ck(_tb_network,_uid)
    if type(_tb_network) ~= "table" then return end
    local pTime = _tb_network.pTime or 10
    local maxReqs = _tb_network.maxReqs or 50
    local ip_count = limit_ip_dict:get(_uid)
    if ip_count == nil then
        limit_ip_dict:set(_uid,1,pTime)
        return
    else
        if ip_count >= maxReqs then
            limit_ip_dict:delete(_uid)
            return true
        else
            limit_ip_dict:incr(_uid,1)
            return
        end
    end
end

--- 匹配 host 和 uri
local function host_uri_remath(_host,_uri)
    if remath_ext(host,_host) and remath_ext(uri,_uri) then
        return true
    end
end

--- 拦截计数 2016年6月7日 21:52:52 up 从全局变成local
local set_count_dict = optl.set_count_dict

-- 执行拦截（deny）操作
local function action_deny()
    action_tag = "deny"
    -- 2016年9月19日
    -- 增加Mod_state = log , host_Mod state = log
    -- 在拒绝请求都进行了log记录，仅ip黑名单的没有记录（因为量的问题），故可直接return
    if config_base.Mod_state == "log" or host_Mod_state == "log" then
        return
    end
    local denyhtml = tostring(config_base.denyMsg.msg)
    local denycode = config_base.denyMsg.http_code or 403
    if config_base.denyMsg.state == "on" then
        local tb = getDict_Config("denyMsg")
        local host_deny_msg = tb[host] or {}
        next_ctx.http_code = host_deny_msg.http_code or denycode
        denyhtml = host_deny_msg.deny_msg or denyhtml
    else
        next_ctx.http_code = denycode
    end
    --ngx.header.content_type = "text/html"
    ngx.say(denyhtml)
    ngx.exit(200)
end

-- action = {allow,deny,log}
-- 执行 动作时 的 log/计数（拦截操作） 操作
local function do_action(_action,_mod_name,_id,_obj)
    _id = _id or tostring(_id)
    if _action == "allow" then
        return true
    elseif _action == "deny" then
        set_count_dict(_mod_name.." deny count")
        next_ctx.waf_log = next_ctx.waf_log or "[".._mod_name.."] deny No: ".._id
        action_deny()
    elseif _action == "log" then
        set_count_dict(_mod_name.." log count")
        next_ctx.waf_log = next_ctx.waf_log or "[".._mod_name.."] log No: ".._id
    end
    return false
end

-- 获取post_form表单数据
local function get_post_form(_len)
    if _len <= 0 then _len = nil end
    if posts_all == nil then
        posts_all = optl.get_post_all()
        base_msg.posts_all = posts_all
    end
    local parser = require "bodyparser"
    local p, err = parser.new(posts_all, http_content_type,_len)
    if p then
        local tmp_tb = {}
        while true do
           local part_body, name, mime, filename = p:parse_part()
           if not part_body then
              break
           end
           table_insert(tmp_tb, {name,filename,mime,part_body})
        end
        base_msg.post_form = tmp_tb
    end
end

---  SETP 0
-- 获取用户真实IP（如有CDN情况下，从header头取）
if config_is_on("realIpFrom_Mod") then
    ip = optl.loc_getRealIp(remoteIp,getDict_Config("realIpFrom_Mod")[host])
    base_msg.ip = ip
end

---  STEP 1
-- black/white ip 访问控制(黑/白名单/log记录) [ip类拦截数据太多未写日志，可自行取消next_ctx.waf_log赋值的注释]
-- 2016年7月29日19:12:53 检查
if config_is_on("ip_Mod") then
    local _ip_v = ip_dict:get(ip) --- 全局IP 黑白名单
    if _ip_v == nil then
        -- nothing
    elseif _ip_v == "allow" then -- 跳出后续规则
        return
    elseif _ip_v == "log" then
        set_count_dict(ip.." log count")
         --next_ctx.waf_log = "[ip_Mod] log"
    else
        --next_ctx.waf_log = "[ip_Mod] deny"
        set_count_dict(ip)
        action_deny()
    end
    -- 基于host的ip黑白名单 eg:www.abc.com_101.111.112.113
    local tmp_host_ip = host.."_"..ip
    local host_ip = ip_dict:get(tmp_host_ip)
    if host_ip == nil then
        -- nothing
    elseif host_ip == "allow" then -- 跳出后续规则
        return
    elseif host_ip == "log" then
        set_count_dict(tmp_host_ip.." log count")
         --next_ctx.waf_log = "[host_ip_Mod] log"
    else
        --next_ctx.waf_log = "[host_ip_Mod] deny"
        set_count_dict(tmp_host_ip)
        action_deny()
    end
    -- 基于 业务属性 进行拦截
    local host_guid_name = host_dict:get(host.."_guid")
    if host_guid_name then
        -- 基于业务属性 拦截
        -- 获取当前请求的业务属性 ngx.var[%guid%]
        -- %host%..ngx.var[%guid_name%]
        local tmp_gd = ngx_var[host_guid_name]
        if tmp_gd then
            local ip_dict_get_guid = ip_dict:get(host.."_"..tmp_gd)
            if ip_dict_get_guid then
                -- next_ctx.waf_log = "[ip_Mod：业务属性] deny"
                action_deny()
            end
        end
    end
end

---  STEP 2
-- host and method  仅允许 访问控制
if config_is_on("host_method_Mod") and action_tag == "" then
    local tb_mod = getDict_Config("host_method_Mod")
    local check = "deny"
    for _,v in ipairs(tb_mod) do
        if v.state == "on" and remath_ext(host,v.hostname) and remath_ext(method,v.method) then
            check = "next"
            break
        end
    end
    if check == "deny" then
        set_count_dict("host_method_Mod deny count")
         next_ctx.waf_log = next_ctx.waf_log or "[host_method_Mod] deny"
         action_deny()
    end
end

--- STEP 3
-- rewrite 跳转阶段(set_cookie)
-- 本来想着放到rewrite阶段使用的，方便统一都放到access阶段了。
if config_is_on("rewrite_Mod") and action_tag == "" then
    local tb_mod = getDict_Config("rewrite_Mod")
    for _,v in ipairs(tb_mod) do
        if v.state == "on" and host_uri_remath(v.hostname,v.uri) then

            if v.action == "set_cookie" then
                local token = ngx.md5(v.set_cookie[1] .. ip)
                local token_name = v.set_cookie[2] or "token"
                -- 没有设置 tokenname 默认就是 token
                if ngx_var["cookie_"..token_name] ~= token then
                    ngx.header["Set-Cookie"] = {token_name.."=" .. token}
                    if method == "POST" then
                        return ngx.redirect(request_uri,307)
                    else
                        return ngx.redirect(request_uri)
                    end
                end
            elseif v.action == "set_url" then
            -- 备用 使用url尾巴跳转方式进行验证

            end

        end
    end
end

--- STEP 4
-- host_Mod 规则过滤
-- 动作支持 （allow deny log）
if  host_Mod_state == "on" and action_tag == "" then
    -- 后续 可能缓存起来，不用每次都进行 序列化操作
    local tb = optl.stringTojson(host_dict:get(host.."_HostMod"))
    for i,v in ipairs(tb) do
        if v.state == "on" and remath_ext(uri,v.uri) then
            if v.app_ext then
                if type(v.post_form) == "number" and method == "POST" and base_msg.post_form == nil then
                    local post_form_n = v.post_form
                    local base_post_from_n = tonumber(config_base.post_form) or 0
                    post_form_n = math_min(post_form_n,base_post_from_n)
                    get_post_form(post_form_n)
                end
                if optl.re_app_ext(v.app_ext,base_msg) then
                    if do_action(v.action,"host_Mod",i) then
                        return
                    else
                        break
                    end
                end
            elseif v.network then
                local blacktime = v.network["blacktime"] or 600
                if v.network.guid and ngx_var[v.network.guid] then
                    -- 业务属性 计数
                    local guid_value = ngx_var[v.network.guid]
                    local mod_host_guid = host..guid_value.." host_network No "..i
                    if network_ck(v.network,mod_host_guid) then
                        host_dict:safe_set(host.."_guid",v.network.guid,blacktime)
                        ip_dict:safe_set(host.."_"..guid_value,mod_host_guid,blacktime)
                        next_ctx.waf_log = next_ctx.waf_log or "[host_Mod] deny No: "..i
                        -- network 触发直接拦截
                        set_count_dict(host.." deny count")
                        action_deny()
                        break
                    end
                else
                    -- ip 计数
                    local mod_host_ip = host.."_"..ip.." host_network No "..i
                    if network_ck(v.network,mod_host_ip) then
                        ip_dict:safe_set(host.."_"..ip,mod_host_ip,blacktime)
                        next_ctx.waf_log = next_ctx.waf_log or "[host_Mod] deny No: "..i
                        -- network 触发直接拦截
                        set_count_dict(host.." deny count")
                        action_deny()
                        break
                    end
                end
            end
        end
    end
end

-- --- STEP 5
-- -- app_Mod 访问控制 （自定义action）
-- -- 目前支持的 deny allow log rehtml refile relua relua_str
-- 支持 规则组 取反 or/and 连接符
if config_is_on("app_Mod") and action_tag == "" then
    local app_mod = getDict_Config("app_Mod")
    for i,v in ipairs(app_mod) do
        if v.state == "on" and host_uri_remath(v.hostname,v.uri) then
            if type(v.post_form) == "number" and method == "POST" and base_msg.post_form == nil then
                local post_form_n = v.post_form
                local base_post_from_n = tonumber(config_base.post_form) or 0
                post_form_n = math_min(post_form_n,base_post_from_n)
                get_post_form(post_form_n)
            end
            if v.app_ext == nil or optl.re_app_ext(v.app_ext,base_msg) then

                if v.action[1] == "deny" then

                    set_count_dict("app deny count")
                    next_ctx.waf_log = next_ctx.waf_log or "[app_Mod] deny No: "..i
                    action_deny()
                    break

                elseif v.action[1] == "allow" then

                    return

                elseif v.action[1] == "log" then
                    if method == "POST" and posts_all == nil then
                        posts_all = optl.get_post_all()
                        base_msg.posts_all = posts_all
                    end
                    optl.writefile(config_base.logPath.."app.log","log Msg : \n"..optl.tableTojson(base_msg))
                    -- app_Mod的action=log单独记录，用于debug调试

                elseif v.action[1] == "rehtml" then
                    optl.sayHtml_ext(v.rehtml,true)
                    break

                elseif v.action[1] == "refile" then
                    optl.sayFile(config_base.htmlPath..v.refile[1],v.refile[2])
                    break

                -- 2016年10月27日 新增 动态执行lua字符串
                elseif v.action[1] == "relua_str" then
                    local re_lua_do = loadstring(v.relua_str)
                    if re_lua_do() == "break" then
                        ngx.exit(200)
                    end

                elseif v.action[1] == "relua" then
                    local re_saylua = optl.sayLua(config_base.htmlPath..v.relua)
                    if re_saylua == "break" then
                        ngx.exit(200)
                    end

                elseif v.action[1] == "set" then -- 预留

                end
            end

        end
    end
end

-- --- STEP 6
-- -- referer过滤模块
--  动作支持（allow deny log）
if config_is_on("referer_Mod") and action_tag == "" then
    local ref_mod = getDict_Config("referer_Mod")
    for i, v in ipairs( ref_mod ) do
        if v.state == "on" and host_uri_remath(v.hostname,v.uri) and remath_ext(referer,v.referer) then
            local _action = v.action or "deny"
            if do_action(_action,"uri_Mod",i) then
                return
            else
                break
            end
        end
    end
end

--- STEP 7
-- uri 过滤(黑/白名单/log)
if config_is_on("uri_Mod") and action_tag == "" then
    local uri_mod = getDict_Config("uri_Mod")
    for i, v in ipairs( uri_mod ) do
        if v.state == "on" and host_uri_remath(v.hostname,v.uri) then
            local _action = v.action or "deny"
            if do_action(_action,"uri_Mod",i) then
                return
            else
                break
            end
        end
    end
end

--- STEP 8
-- header 过滤(黑名单) [scanner]
if config_is_on("header_Mod") and action_tag == "" then
    local tb_mod = getDict_Config("header_Mod")
    for i,v in ipairs(tb_mod) do
        if v.state == "on" and host_uri_remath(v.hostname,v.uri) then
            if optl.action_remath("headers",v.header,base_msg) then
                set_count_dict("header deny count")
                 next_ctx.waf_log = next_ctx.waf_log or "[header_Mod] deny No: "..i
                 action_deny()
                 break
            end
        end
    end
end

--- STEP 9
-- useragent(黑、白名单/log记录)
if config_is_on("useragent_Mod") and action_tag == "" then
    local uagent_mod = getDict_Config("useragent_Mod")
    for i, v in ipairs( uagent_mod ) do
        if v.state == "on" and remath_ext(host,v.hostname) and remath_ext(useragent,v.useragent) then
            local _action = v.action or "deny"
            if do_action(_action,"useragent_Mod",i) then
                return
            else
                break
            end
        end
    end
end

--- STEP 10
-- cookie (黑/白名单/log记录)
if config_is_on("cookie_Mod") and action_tag == "" then
    local cookie_mod = getDict_Config("cookie_Mod")
    for i, v in ipairs( cookie_mod ) do
        if v.state == "on" and remath_ext(host,v.hostname) and remath_ext(cookie,v.cookie) then
            local _action = v.action or "deny"
            if do_action(_action,"cookie_Mod",i) then
                return
            else
                break
            end
        end
    end
end

--- STEP 11
-- args [args_data] (黑/白名单/log记录)
if config_is_on("args_Mod") and action_tag == "" then
    if config_base.args_Mod["HPP_state"] == "on" then
        for k,v in pairs(args) do
            if type(v) == "table" then
                do_action("deny","args_HPP","0")
                break
            end
        end
    end
    if action_tag == "" then
        local args_mod = getDict_Config("args_Mod")
        for i,v in ipairs(args_mod) do
            if v.state == "on" and remath_ext(host,v.hostname) and remath_ext(args_data,v.args_data) then
                local _action = v.action or "deny"
                if do_action(_action,"args_Mod",i) then
                    return
                else
                    break
                end
            end
        end
    end
end

--- STEP 12
-- post (黑/白名单)
if config_is_on("post_Mod") and action_tag == "" and method == "POST" then
    if config_base.post_Mod["HPP_state"] == "on" then
        for k,v in pairs(posts) do
            if type(v) == "table" then
                do_action("deny","posts_HPP","0")
                break
            end
        end
    end
    if action_tag == "" then
        local post_mod = getDict_Config("post_Mod")
        for i,v in ipairs(post_mod) do
            if v.state == "on" and remath_ext(host,v.hostname) and remath_ext(posts_data,v.posts_data) then
                local _action = v.action or "deny"
                if do_action(_action,"post_Mod",i) then
                    return
                else
                    break
                end
            end
        end
    end
end

--- STEP 13
-- network_Mod 访问控制
if config_is_on("network_Mod") and action_tag == "" then
    local tb_networkMod = getDict_Config("network_Mod")
    for i, v in ipairs( tb_networkMod ) do
        if v.state =="on" and host_uri_remath(v.hostname,v.uri) then
            local blacktime = v.network.blackTime or 10*60
            -- 业务属性 计数
            if v.network.guid and ngx_var[v.network.guid] then
                local guid_value = ngx_var[v.network.guid]
                local mod_host_guid = host..guid_value.." network_Mod No "..i
                if network_ck(v.network,mod_host_guid) then
                    host_dict:safe_set(host.."_guid",v.network.guid,blacktime)
                    ip_dict:safe_set(host.."_"..guid_value,mod_host_guid,blacktime)
                    next_ctx.waf_log = next_ctx.waf_log or "[network_Mod] deny No: "..i
                    action_deny()
                    break
                end
            else
                -- ip 属性 计数
                local deny_guid = ip.." network_Mod No "..i
                if network_ck(v.network,deny_guid) then
                    if v.hostname[2] == "" then
                        if v.hostname[1] == "*" then
                            ip_dict:safe_set(ip,deny_guid,blacktime)
                        else
                            ip_dict:safe_set(host.."_"..ip,deny_guid,blacktime)
                        end
                    else
                        ip_dict:safe_set(host.."_"..ip,deny_guid,blacktime)
                    end
                    next_ctx.waf_log = next_ctx.waf_log or "[network_Mod] deny  No: "..i
                    action_deny()
                    --ngx.say("frist network deny")
                    break
                end
            end
        end
    end
end

--- STEP 14
if config_is_on("replace_Mod") and action_tag == "" then
    local Replace_Mod = getDict_Config("replace_Mod")
    for _,v in ipairs(Replace_Mod) do
        if v.state =="on" and host_uri_remath(v.hostname,v.uri) then
            ngx.req.clear_header("Accept-Encoding")-- 取消浏览器要求gzip操作)
            next_ctx.replace_Mod = v
            --ngx_ctx.body_mod = v
            break
        end
    end
end