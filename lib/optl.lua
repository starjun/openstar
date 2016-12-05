
-- 用于生成唯一随机字符串
local random = require "resty-random"

local cjson_safe = require "cjson.safe"

local token_dict = ngx.shared.token_dict
local count_dict = ngx.shared.count_dict
local config_dict = ngx.shared.config_dict
local config_base = cjson_safe.decode(config_dict:get("base")) or {}

--- 文件读写
local function readfile(_filepath)
    -- local fd = assert(io.open(_filepath,"r"),"readfile io.open error")
    local fd,err = io.open(_filepath,"r")
    if fd == nil then 
        ngx.log(ngx.ERR,"readfile error",err)
        return
    end
    local str = fd:read("*a") --- 全部内容读取
    fd:close()
    return str
end

-- 默认写文件错误时，会将错误信息和_msg数据使用ngx.log写到错误日志中。
-- ngx.log对写入的信息进行了大小控制，一些大数据情况理论上不用担心
-- 自己调用时，_msg的内容大小需要自己进行控制
local function writefile(_filepath,_msg,_ty)
    _ty = _ty or "a+"
    -- w+ 覆盖 写文件方式默认是追加方式
    -- local fd = assert(io.open(_filepath,_ty),"writefile io.open error")
    local fd,err = io.open(_filepath,_ty)
    if fd == nil then 
        ngx.log(ngx.ERR,"writefile msg : "..tostring(_msg),err)
        return 
    end -- 文件读取错误返回
    fd:write("\n"..tostring(_msg))
    fd:flush()
    fd:close()
    return true
end

--- table/string转换
local function tableTostring(_obj)
        local lua = ""  
        local t = type(_obj)  
        if t == "number" then  
            lua = lua .. _obj  
        elseif t == "boolean" then  
            lua = lua .. tostring(_obj)  
        elseif t == "string" then  
            lua = lua .. string.format("%q", _obj)  
        elseif t == "table" then  
            lua = lua .. "{\n"  
        for k, v in pairs(_obj) do  
            lua = lua .. "[" .. tableTostring(k) .. "]=" .. tableTostring(v) .. ",\n"  
        end  
        local metatable = getmetatable(_obj)  
            if metatable ~= nil and type(metatable.__index) == "table" then  
            for k, v in pairs(metatable.__index) do  
                lua = lua .. "[" .. tableTostring(k) .. "]=" .. tableTostring(v) .. ",\n"  
            end  
        end  
            lua = lua .. "}"  
        elseif t == "nil" then  
            return nil  
        else  
            error("can not tableToString a " .. t .. " type.")  
        end  
        return lua  
end

local function stringTotable(_str)
    if _str == nil then return end
    local ret = loadstring("return ".._str)()  
    return ret
end

-- table转成json字符串
local function tableTojson(_obj)
    local json_text = cjson_safe.encode(_obj)  
    return json_text
end

-- 字符串转成序列化后的json同时也可当table类型
local function stringTojson(_obj)
    local json = cjson_safe.decode(_obj) or {}
    return json
end

local function guid(_num)
    _num = _num or 10
    return string.format('%s-%s',
        random.token(_num),
        random.token(_num)
    )
end

-- 设置token 并缓存3分钟
-- 可能会无限循环
local function set_token(_token,_t,_len)
    _len = _len or 10
    _token = _token or guid(_len)    
    _t = _t or 2*60
    local re = token_dict:add(_token,true,_t)  --- -- 缓存2分钟 非重复插入
    if re then
        return _token
    else
        return set_token(nil,_t,_len +１)
    end
end

local function del_token(_token)
    token_dict:delete(_token)
end

--- 基础 常用二阶匹配规则
-- 说明：[_restr,_options]  _str 就是被匹配的内容
-- eg "ip":["*",""]
-- eg "hostname":[["www.abc.com","127.0.0.1"],"table"]
local function remath(_str,_re_str,_options)
    if _str == nil or _re_str == nil or _options == nil then return false end
    if _options == "" then
    -- 纯字符串匹配 * 表示任意
        if _str == _re_str or _re_str == "*" then
            return true
        end
    elseif _options == "table" then
    -- table 匹配，在table中 字符串完全匹配
        if type(_re_str) ~= "table" then return false end
        for i,v in ipairs(_re_str) do
            if v == _str then
                return true
            end
        end
    elseif _options == "in" then 
    --- 用于包含 查找 string.find
        local from , to = string.find(_str, _re_str)
        --if from ~= nil or (from == 1 and to == 0 ) then
        --当_re_str=""时的情况 没有处理
        if from ~= nil then
            return true
        end
    elseif _options == "list" then
    --- list 匹配，o(1) 比table要好些， 字符串完全匹配
        if type(_re_str) ~= "table" then return false end
        local re = _re_str[_str]
        if re == true then -- 需要判断一下 有可能是值类型的值
            return true
        end
    elseif _options == "@token@" then
    --- 服务端对token的合法性进行匹配
        local a = tostring(token_dict:get(_str))
        if a == _re_str then 
            token_dict:delete(_str) -- 使用一次就删除token
            return true
        end
    elseif _options == "cidr" then
    --- 基于cidr，用于匹配ip 是否在 ip段中
        if type(_re_str) ~= "table" then return false end
        for i,v in ipairs(_re_str) do

            local cidr = require "cidr"
            local first_address, last_address = cidr.parse_cidr(v)  
            --ip_cidr formats like 192.168.10.10/24

            local ip_num = cidr.ip_2_number(_str)  
            --// get the ip to decimal.

            if ip_num >= first_address and ip_num <= last_address then  
            --// judge if ip lies between the cidr.
                return true
            end
        end
    else
    --- 正则匹配
        local from, to = ngx.re.find(_str, _re_str, _options)
        if from ~= nil then
            return true,string.sub(_str, from, to)
        end
    end
end

--- 判断config_dict中模块开关是否开启
local function config_is_on(_config_arg)
    if config_base[_config_arg] == "on" then
        return true
    end
end

--- 取config_dict中的json数据
local function getDict_Config(_Config_jsonName)
    local re = cjson_safe.decode(config_dict:get(_Config_jsonName)) or {}
    return re
end

-- 传入 (host,remoteIp)
-- ipfromset.ips 异常处理
local function loc_getRealIp(_host,_remoteIp)
    if config_is_on("realIpFrom_Mod") then
        local realipfrom = getDict_Config("realIpFrom_Mod")
        local ipfromset = realipfrom[_host]
        if type(ipfromset) ~= "table" or type(ipfromset.ips) ~= "table" then 
            return _remoteIp 
        end
        if remath(_remoteIp,ipfromset.ips[1],ipfromset.ips[2]) then
            --- header 中key名称 - 需要转换成 _
            local x = 'http_'..ngx.re.gsub(tostring(ipfromset.realipset),'-','_')
            local ip = ngx.unescape_uri(ngx.var[x])
            if ip == "" then
                ip = _remoteIp
            end
            return ip
        else
            return _remoteIp
        end
    else
        return _remoteIp
    end
end

-- 增加 三阶匹配规则
local function remath3(_tbMod,_modrule)
    if type(_tbMod) ~= "table" or type(_modrule) ~= "table" then 
        return false 
    end
    
    local _re_str = _modrule[1]
    local _options = _modrule[2]
    local _str = _tbMod[_modrule[3]]
    -- 取 args/headers 中某一个key (_str可能是一个table)
    local _ty = _modrule[4] or 1

    if type(_str) == "table" then
        if _ty == "end" then
            _ty = table.maxn(_str)
            if remath(_str[_ty],_re_str,_options) then
                return true
            end
        elseif _ty == "all" then
            for i,v in ipairs(_str) do
                if remath(v,_re_str,_options) then
                    return true
                end
            end
        else -- table 中的某一个
            -- 超出范围判断
            if _ty > table.maxn(_str) then  
                _ty = 1
            else
                _ty = table.maxn(_str)
            end
            if remath(_str[_ty],_re_str,_options) then
                return true
            end
        end
    else
        if remath(_str,_re_str,_options) then
            return true
        end
    end
end

-- 基于modName 进行规则判断
-- _modName = uri host args cookie 等
-- _modRule = ["*",""] ["admin","in"] ["\w{6}","jio"] 
-- ["asd","in","args_name1"] ["asd","in","args_name1","all"] ["asd","in","args_name1","end"]
local function action_remath(_modName,_modRule,_base_Msg)

    if _modName == nil or _base_Msg == nil or type(_modRule) ~= "table" then 
        return false 
    end
    if type(_base_Msg[_modName]) == "table" then
        if remath3(_base_Msg[_modName],_modRule) then
            return true
        end
    else
        if remath(_base_Msg[_modName],_modRule[1],_modRule[2]) then
            return true
        end
    end

    -- 明细写法
        -- if _modName == "remoteIp" then
        --     if remath(_base_Msg[_modName],_modRule[1],_modRule[2]) then
        --         return true
        --     end
        -- elseif _modName == "host" then
        --     if remath(_base_Msg[_modName],_modRule[1],_modRule[2]) then
        --         return true
        --     end
        -- elseif _modName == "method" then
        --     if remath(_base_Msg[_modName],_modRule[1],_modRule[2]) then
        --         return true
        --     end
        -- elseif _modName == "uri" then
        --     if remath(_base_Msg[_modName],_modRule[1],_modRule[2]) then
        --         return true
        --     end
        -- elseif _modName == "request_uri" then
        --     if remath(_base_Msg[_modName],_modRule[1],_modRule[2]) then
        --         return true
        --     end
        -- elseif _modName == "useragent" then
        --     if remath(_base_Msg[_modName],_modRule[1],_modRule[2]) then
        --         return true
        --     end
        -- elseif _modName == "referer" then
        --     if remath(_base_Msg[_modName],_modRule[1],_modRule[2]) then
        --         return true
        --     end
        -- elseif _modName == "cookie" then
        --     if remath(_base_Msg[_modName],_modRule[1],_modRule[2]) then
        --         return true
        --     end
        -- elseif _modName == "query_string" then
        --     if remath(_base_Msg[_modName],_modRule[1],_modRule[2]) then
        --         return true
        --     end
        -- -- table 类型
        -- elseif _modName == "headers" then
        --     if remath3(_base_Msg[_modName],_modRule) then
        --         return true
        --     end
        -- elseif _modName == "args" then
        --     if remath3(_base_Msg[_modName],_modRule) then
        --         return true
        --     end
        -- end
end

-- 对 or 规则list 进行判断
local function or_remath(_or_list,_basemsg)
    -- or 匹配 任意一个为真 则为真
    if type(_or_list) ~= "table" then return false end
    for i,v in ipairs(_or_list) do
        if v[1] then --  取反
            if not action_remath(v[2],v[3],_basemsg) then -- 真
                return true
            else
            
            end
        else
            if action_remath(v[2],v[3],_basemsg) then -- 真
                return true
            else
            
            end
        end
    end
    return false
end

-- 对自定义规则列表进行判断
-- 传入一个规则列表 和 base_msg
-- [false,"uri",["admin","in"],"and"]
-- [true,"cookie",["\\w{5}","jio"],"or"]
-- [true,"referer",["baidu","in"]]
local function re_app_ext(_app_list,_basemsg)
    if type(_app_list) ~= "table" or type(_basemsg) ~= "table" then return false end
    local list_cnt = table.maxn(_app_list)
    local tmp_or = {}
    for i,v in ipairs(_app_list) do
        if v[4] == "or" then
            table.insert(tmp_or,v)
            if i == list_cnt then
                if or_remath(tmp_or,_basemsg) then -- 真

                else
                    tmp_or = {} -- 情况 or 列表
                    return false
                end
                break            
            end            
        else
            if table.maxn(tmp_or) == 0 then -- 前面没 or
                if v[1] then --取反
                    if not action_remath(v[2],v[3],_basemsg) then -- 真

                    else -- 假 跳出
                        return false
                    end
                else
                    if action_remath(v[2],v[3],_basemsg) then -- 真

                    else -- 假 跳出
                        return false
                    end
                end
            else -- 一组 or 计算
                table.insert(tmp_or, v)
                if or_remath(tmp_or,_basemsg) then -- 真

                else                    
                    return false
                end
                tmp_or = {} -- 清空 or 列表
            end
        end
    end
    return true
end

--- 拦截计数
-- set失败未处理
local function set_count_dict(_key)
    if _key == nil then return end
    local re, err = count_dict:incr(_key,1)
    if re == nil then
       count_dict:set(_key,1)
    end
end

--- 替换方式比较简单（全局替换），先这么用吧
local function ngx_find(_str)
    -- str = string.gsub(str,"@ngx_time@",ngx.time())
    -- ngx.re.gsub 效率要比string.gsub要好一点，参考openresty最佳实践
    _str = tostring(_str)
    _str = ngx.re.gsub(_str,"@ngx_localtime@",tostring(ngx.localtime()))

    -- string.find 字符串 会走jit,所以就没有用ngx模块
    -- 当前情况下，对token仅是全局替换一次，请注意
    if string.find(_str,"@token@") ~= nil then       
        _str = ngx.re.gsub(_str,"@token@",tostring(set_token()))
    end 
    return _str
end

--- 对not table 类型的数据 进行 ngx_find
local function sayHtml_ext(_html,_ty) 
    ngx.header.content_type = "text/html"    
    if _html == nil then 
        _html = "_html is nil"
    elseif type(_html) == "table" then             
        _html = tableTojson(_html)       
    end

    if _ty ~= nil then
        _html = ngx_find(_html)
    end

    ngx.say(_html)
    ngx.exit(200)
end

--- ngx_find 无条件使用
local function sayFile(_filename)
    ngx.header.content_type = "text/html"
    --local str = readfile(Config.base.htmlPath..filename)
    local str = readfile(_filename) or "filename error"
    -- 对读取的文件内容进行 ngx_find
    ngx.say(ngx_find(str))
    ngx.exit(200)
end

local function sayLua(_luapath)
    --local re = dofile(Config.base.htmlPath..lua)
    local re = dofile(_luapath)
    return re
end

-- 记录debug日志
-- 更新记录IP 2016年6月7日 22:22:15
-- 目录配置异常，则log路径就是 /tmp/
-- 参数循序 base_msg info filename
local function debug(_base_msg,_info,_filename)
    if config_base.debug_Mod == false then return end --- 判断debug开启状态
    if _filename == nil then
        _filename = "debug.log"
    end
    local filepath = config_base.logPath or "/tmp/"
    filepath = filepath.._filename

    local remoteIp = _base_msg.remoteIp
    local host = _base_msg.host
    local ip = _base_msg.ip
    if remoteIp == ip then
        ip = "-"
    end    
    local time = ngx.localtime()
    local method = _base_msg.method
    local status = ngx.var.status
    local request_uri = _base_msg.request_uri
    local uri = _base_msg.uri
    local useragent = _base_msg.useragent
    local referer = _base_msg.referer
    local str = string.format([[%s "%s" "%s" [%s] "%s" "%s" "%s" "%s" "%s" "%s"]],
        remoteIp,host,ip,time,method,status,uri,useragent,referer,_info)
    
    writefile(filepath,str)
end

--- 请求相关 正常使用阶段在access/rewrite set没测试过

    --- 获取单个args值
    local function get_argsByName(_name)
        if _name == nil then return "" end
        local x = 'arg_'.._name
        local _name = ngx.unescape_uri(ngx.var[x])
        return _name
        -- local args_name = ngx.req.get_uri_args()[_name]
        -- if type(args_name) == "table" then args_name = args_name[1] end
        -- return ngx.unescape_uri(args_name)
    end

    --- 获取所有args参数[query_string]
    local function get_args()
        return ngx.unescape_uri(ngx.var.query_string)
    end

    --- 获取单个post值 非POST方法使用会异常
    local function get_postByName(_name)
        if _name == nil then return "" end
        ngx.req.read_body()
        local posts_name = ngx.req.get_post_args()[_name]
        if type(posts_name) == "table" then posts_name = posts_name[1] end
        return ngx.unescape_uri(posts_name)
    end

    --- 获取所有POST参数（包含表单）
    local function get_posts()   
        ngx.req.read_body()
        local data = ngx.req.get_body_data() -- ngx.req.get_post_args()
        if not data then 
            local datafile = ngx.req.get_body_file()
            if datafile then
                local fh, err = io.open(datafile, "r")
                if fh then
                    fh:seek("set")
                    data = fh:read("*a")
                    fh:close()
                end
            end
        end
        return ngx.unescape_uri(data)
    end

    --- 获取header原始字符串
    local function get_headers(_bool)
        -- _bool 是否包含 `GET / HTTP/1.1` 请求头
        return ngx.unescape_uri(ngx.req.raw_header(_bool))
    end

local optl={}

--- 文件读写
optl.readfile = readfile
optl.writefile = writefile

--- table转换
optl.tableTostring = tableTostring
optl.stringTotable = stringTotable

optl.tableTojson = tableTojson
optl.stringTojson = stringTojson

--- ==
optl.random = random
optl.guid = guid
optl.set_token = set_token
optl.del_token = del_token

optl.remath = remath
optl.config_is_on = config_is_on
optl.getDict_Config = getDict_Config

optl.set_count_dict = set_count_dict
optl.ngx_find = ngx_find

optl.re_app_ext = re_app_ext
optl.action_remath = action_remath
--- say相关
optl.sayHtml_ext = sayHtml_ext
optl.sayFile = sayFile
optl.sayLua = sayLua

--- log 相关
optl.debug = debug

--- 请求相关
optl.get_argsByName = get_argsByName
optl.get_args = get_args
optl.get_postByName = get_postByName
optl.get_posts = get_posts
optl.get_headers = get_headers

return optl