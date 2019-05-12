
-- 用于生成唯一随机字符串
local random = require "resty-random"
local stool = require "stool"
local cjson_safe = require "cjson.safe"
local ngx_re_find = ngx.re.find
local ngx_re_gsub = ngx.re.gsub
local ngx_unescape_uri = ngx.unescape_uri

local token_dict = ngx.shared.token_dict
local count_dict = ngx.shared.count_dict
local config_dict = ngx.shared.config_dict
local config = cjson_safe.decode(config_dict:get("config")) or {}
local config_version = 0

--- 读取文件（全部读取/按行读取）
local function readfile(_filepath,_ty)
    local fd = io.open(_filepath,"r")
    if not fd then return end
    if not _ty then
        local str = fd:read("*a") --- 全部内容读取
        fd:close()
        return str
    else
        local line_s = {}
        for line in fd:lines() do
            table.insert(line_s, line)
        end
        fd:close()
        return line_s
    end
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
    fd:write(tostring(_msg))
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
    if not _str then return end
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

-- 设置token 并缓存2分钟
local function set_token(_token,_t,_len)
    _len = _len or 10
    local _lenNext = _len + 1
    _token = _token or guid(_len)
    _t = _t or 2*60
    local re = token_dict:add(_token,true,_t)  --- -- 缓存2分钟 非重复插入
    if re then
        return _token
    else
        return set_token(guid(_lenNext),_t,_lenNext)
    end
end

local function del_token(_token)
    token_dict:delete(_token)
end

--- 基础 常用二阶匹配规则
-- 说明：[_restr,_options]  _str 就是被匹配的内容
-- eg "ip":["*",""]
-- eg "hostname":[["www.abc.com","127.0.0.1"],"list"]
local function remath(_str,_re_str,_options)
    if _str == nil or _re_str == nil or _options == nil then return false end
    if _options == "" or _options == "=" then
        -- 纯字符串匹配 * 表示任意
        if _str == _re_str or _re_str == "*" then
            return true
        end
    elseif _options == "list" then
        return stool.isInArrayTb(_str,_re_str)
    elseif _options == "in" then
        return stool.stringIn(_str,_re_str)
        -- add new type
    elseif _options == "len" then
        if type(_re_str) ~= "table" then return false end
        local len_str = #_str
        if len_str >= _re_str[1] and len_str <= _re_str[2] then
            return true
        end
    elseif _options == "start_list" then
        if type(_re_str) ~= "table" then return false end
        for _,v in ipairs(_re_str) do
            if stool.stringStarts(_str,v) then
                return true
            end
        end
    elseif _options == "end_list" then
        if type(_re_str) ~= "table" then return false end
        for _,v in ipairs(_re_str) do
            if stool.stringEnds(_str,v) then
                return true
            end
        end
    elseif _options == "in_list" then
        if type(_re_str) ~= "table" then return false end
        for _,v in ipairs(_re_str) do
            if stool.stringIn(_str,v) then
                return true
            end
        end
    elseif _options == "rein_list" then
        if type(_re_str) ~= "table" then return false end
        for _,v in ipairs(_re_str) do
            if stool.stringIn(_str,string.upper(v)) then
                return true
            end
        end
    elseif _options == "dict" then
        --- 字典(dict) 匹配，o(1) 比序列(list)要好些， 字符串完全匹配
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
        for _,v in ipairs(_re_str) do

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
        local from, to = ngx_re_find(_str, _re_str, _options)
        if from ~= nil then
            -- payload
            -- start_num,end_num
            local start_num = from
            if from > 5 then
                start_num = from - 5
            end
            local end_num = to
            if (#_str - to) > 5 then
                end_num = to + 5
            end
            return true,string.sub(_str, start_num, end_num)
            --return true
        end
    end
end

--- 扩展 常用二阶匹配规则（支持取反）
-- 说明：[_restr,_options]  _str 就是被匹配的内容
-- eg "ip":["*",""]
-- eg "hostname":[["www.abc.com","127.0.0.1"],"table",false/true]
local function remath_Invert(_str,_re_str,_options,_Invert)
    if _Invert then
        if not remath(_str,_re_str,_options) then
            return true
        end
    else
        if remath(_str,_re_str,_options) then
            return true
        end
    end
end

-- 传入 (remoteIp,ipfrom)
local function loc_getRealIp(_remoteIp,_ipfrom)
    local ipfrom = _ipfrom or {}
    if type(ipfrom.ips) ~= "table" then
        return _remoteIp
    end
    if remath_Invert(_remoteIp,ipfrom.ips[1],ipfrom.ips[2],ipfrom.ips[3]) then
        --- header 中key名称 - 需要转换成 _
        --local x = 'http_'..ngx_re_gsub(tostring(ipfrom.realipfrom),'-','_')
        local x = 'http_'..ipfrom.realipfrom
        local ip = ngx_unescape_uri(ngx.var[x])
        if ip == "" then
            ip = _remoteIp
        end
        return ip
    else
        return _remoteIp
    end
end

-- 增加 三阶匹配规则
--  table 类型
-- _modrule = ["^[\\w]{6}$","jio",["cc",3],true]
-- _modrule = ["true","@token@",["cctoken"],true]
-- _modrule = ["^[\\w]{6}$","jio",["sign"],true]
local function remath3(_tbMod,_modrule)
    local _re_str = _modrule[1]
    local _options = _modrule[2]
    local _str = _tbMod[_modrule[3][1]]

    -- 取 args/posts/headers 中某一个key (_str可能是一个table)
    local _ty = _modrule[3][2] or 1
    local _Invert = _modrule[4]

    if type(_str) == "table" then
        if _ty == "end" then
            _ty = #_str
            if remath_Invert(_str[_ty],_re_str,_options,_Invert) then
                return true
            end
        elseif _ty == "all" then
            for _,v in ipairs(_str) do
                if remath_Invert(v,_re_str,_options,_Invert) then
                    return true
                end
            end
        else -- table 中的某一个
            -- 超出范围判断
            if _ty > #_str then
                _ty = 1
            else
                _ty = #_str
            end
            if remath_Invert(_str[_ty],_re_str,_options,_Invert) then
                return true
            end
        end
    else
        if remath_Invert(_str,_re_str,_options,_Invert) then
            return true
        end
    end
end

-- 增加 post_form的规则匹配
-- _tbMod : [["form name","file name","file type","file msg"],...]
-- _modrule : ["\\.(jpg|jpeg|png|webp|gif)$","jio",["image0",2],true/false/flase]
local function remath_form(_tbMod,_modrule)
    if type(_tbMod) ~= "table" or type(_modrule) ~= "table" then
        return false
    end
    local _re_str = _modrule[1]
    local _options = _modrule[2]
    local _form_name = _modrule[3][1]
    local _form_n = _modrule[3][2]
    local _Invert = _modrule[4]
    if type(_form_n) ~= "number" or _form_n < 1 or _form_n > 4 then
        return false
    end
    for _,v in ipairs(_tbMod) do
        if v[1] == _form_name or _form_name == "*" then
            local _str = v[_form_n]
            if remath_Invert(_str,_re_str,_options,_Invert) then
                return true
            end
        end
    end
end

-- 基于modName 进行规则判断
-- _modName = uri,cookie, args,posts...
-- _modRule = ["admin","in"]
-- _modRule = ["\\w{5}","jio",true]
--  table 类型
-- _modRule = ["^[\\w]{6}$","jio",["cc",3],true]
-- _modRule = ["true","@token@",["cctoken"],true]
-- _modRule = ["^[\\w]{6}$","jio",["sign"]]
local function action_remath(_modName,_modRule,_base_Msg)

    if _modName == nil or type(_base_Msg) ~= "table" or type(_modRule) ~= "table" then
        return false
    end
    if type(_base_Msg[_modName]) == "table" then
        if _modName == "post_form" then
            if remath_form(_base_Msg[_modName],_modRule) then
                return true
            end
        else
            if remath3(_base_Msg[_modName],_modRule) then
                return true
            end
        end
    else
        if _modRule[2] == "rein_list" then
            return remath_Invert(string.upper(_base_Msg[_modName]),_modRule[1],_modRule[2],_modRule[3])
        else
            return remath_Invert(_base_Msg[_modName],_modRule[1],_modRule[2],_modRule[3])
        end
    end
end

-- 对 or 规则list 进行判断
-- _or_list = ["referer",["baidu","in",true]]
-- _or_list = ["args",["^[\\w]{6}$","jio",["cc",3],true],"and"]
local function or_remath(_or_list,_basemsg)
    -- or 匹配 任意一个为真 则为真
    for _,v in ipairs(_or_list) do
        if action_remath(v[1],v[2],_basemsg) then -- 真
            return true
        end
    end
    return false
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
    _str = ngx_re_gsub(_str,"@ngx_localtime@",tostring(ngx.localtime()))

    -- string.find 字符串 会走jit,所以就没有用ngx模块
    -- 当前情况下，对token仅是全局替换一次，请注意
    -- string.find(_str,"@token@") ~= nil
    if stool.stringIn(_str,"@token@")  then
        _str = ngx_re_gsub(_str,"@token@",tostring(set_token()))
    end
    return _str
end

--- 对not table 类型的数据 进行 ngx_find
local function sayHtml_ext(_html,_find_type,_content_type)
    --ngx.header.content_type = "text/html"
    if _html == nil then
        _html = "_html is nil"
    elseif type(_html) == "table" then
        _html = tableTojson(_html)
    end

    if _find_type then
        _html = ngx_find(_html)
    end

    if _content_type then
        ngx.header.content_type = _content_type
    end

    ngx.say(_html)
    ngx.exit(200)
end

--- ngx_find 无条件使用
local function sayFile(_filename,_header)
    --ngx.header.content_type = "text/html"
    --local str = readfile(Config.base.htmlPath..filename)
    local str = readfile(_filename) or "filename error"
    if _header then
        ngx.header.content_type = _header
    end
    -- 对读取的文件内容进行 ngx_find
    ngx.say(ngx_find(str))
    ngx.exit(200)
end

local function sayLua(_luapath)
    --local re = dofile(Config.base.htmlPath..lua)
    local re = dofile(_luapath)
    return re
end

--- 请求相关 正常使用阶段在access/rewrite set没测试过

    --- 获取单个args值
    local function get_argsByName(_name)
        if _name == nil then return "" end
        local x = 'arg_'.._name
        local _name = ngx_unescape_uri(ngx.var[x])
        return _name
        -- local args_name = ngx.req.get_uri_args()[_name]
        -- if type(args_name) == "table" then args_name = args_name[1] end
        -- return ngx_unescape_uri(args_name)
    end

    --- 获取单个post值 非POST方法使用会异常
    local function get_postByName(_name)
        if _name == nil then return "" end
        --ngx.req.read_body()
        local posts_name = ngx.req.get_post_args()[_name]
        if type(posts_name) == "table" then posts_name = posts_name[1] end
        return ngx_unescape_uri(posts_name)
    end

    --- 获取所有POST参数（包含表单）
    local function get_post_all()
        --ngx.req.read_body()
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
        return ngx_unescape_uri(data)
    end

    local function get_table(_tb)
        if _tb == nil then
            return ""
        end
        local tb_args = {}
        for k,v in pairs(_tb) do
            if type(v) == "table" then
                local tmp_v = {}
                for i,vv in ipairs(v) do
                    if vv == true then
                        vv=""
                    end
                    table.insert(tmp_v,vv)
                end
                v = table.concat(tmp_v,",")
            elseif v == true then
                v= ""
            end
            table.insert(tb_args,v)
        end
        return table.concat(tb_args,",")
    end

-- 对自定义规则列表进行判断
-- 传入一个规则列表 和 base_msg
-- _app_list = ["uri",["admin","in"],"and"]
-- _app_list = ["cookie",["\\w{5}","jio",true],"or"]
-- _app_list = ["referer",["baidu","in",true]]
--  table 类型
-- _app_list = ["args",["^[\\w]{6}$","jio",["cc",3],true],"and"]
-- _app_list = ["args",["true","@token@",["cctoken"],true]]
-- _app_list = ["headers",["^[\\w]{6}$","jio",["sign"],true]]
--  post_form 表单
local function re_app_ext(_app_list,_basemsg)
    if type(_app_list) ~= "table" then return false end
    local list_cnt = #_app_list
    local tmp_or = {}
    for i,v in ipairs(_app_list) do
        if v[1] == "posts_all" and _basemsg.posts_all == nil then
            _basemsg.posts_all = get_post_all()
        end
        if v[3] == "or" then
            table.insert(tmp_or,v)
            if i == list_cnt then
                return or_remath(tmp_or,_basemsg)
            end
        else
            if #tmp_or == 0 then -- 前面没 or
                if action_remath(v[1],v[2],_basemsg) then -- 真
                    -- continue
                else -- 假 跳出
                    return false
                end
            else -- 一组 or 计算
                table.insert(tmp_or, v)
                if or_remath(tmp_or,_basemsg) then -- 真
                    -- continue
                else
                    return false
                end
                tmp_or = {} -- 清空 or 列表
            end
        end
    end
    return true
end

local optl={}

-- 配置json
optl.config = config
optl.config_version = config_version

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
optl.remath_Invert = remath_Invert
optl.loc_getRealIp = loc_getRealIp

optl.set_count_dict = set_count_dict
optl.ngx_find = ngx_find

optl.re_app_ext = re_app_ext
optl.action_remath = action_remath
--- say相关
optl.sayHtml_ext = sayHtml_ext
optl.sayFile = sayFile
optl.sayLua = sayLua

--- 请求相关
optl.get_argsByName = get_argsByName
optl.get_postByName = get_postByName
optl.get_post_all = get_post_all
optl.get_table = get_table

return optl