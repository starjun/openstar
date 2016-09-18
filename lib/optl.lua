
--- 文件读写
local function readfile(_filepath)
    -- local fd = assert(io.open(_filepath,"r"),"readfile io.open error")
    local fd,err = io.open(_filepath,"r")
    if fd == nil then 
        ngx.log(ngx.ERR,"readfile error : "..tostring(err))
        return
    end
    local str = fd:read("*a") --- 全部内容读取
    fd:close()
    return str
end

local function writefile(_filepath,_msg,_ty)
    _ty = _ty or "a+"
    -- w+ 覆盖
    -- local fd = assert(io.open(_filepath,_ty),"writefile io.open error")
    local fd,err = io.open(_filepath,_ty)
    if fd == nil then 
        ngx.log(ngx.ERR,"writefile msg : "..tostring(_msg).." error : "..tostring(err))
        return 
    end -- 文件读取错误返回
    fd:write("\n"..tostring(_msg))
    fd:flush()
    fd:close()
end

--- table转换
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

local cjson_safe = require "cjson.safe"

local function tableTojson(_obj)
    local json_text = cjson_safe.encode(_obj)  
    return json_text
end

local function stringTojson(_obj)
    local json = cjson_safe.decode(_obj)  
    return json
end

-- 用于生成唯一随机字符串
local function guid()
    local random = require "resty-random"
    return string.format('%s-%s',
        random.token(10),
        random.token(10)
    )
end


local token_dict = ngx.shared.token_dict

-- 设置token 并缓存3分钟
-- 未做错误处理
local function set_token(_token)
    _token = _token or guid()    
    if token_dict:get(_token) == nil then 
        token_dict:set(_token,true,3*60)  --- -- 缓存3分钟 非重复插入
        return _token
    else
        return set_token()
    end 
end

--- 常用二阶匹配规则
local function remath(_str,_re_str,_options)
    if _str == nil or _re_str == nil or _options == nil then return false end
    if _options == "" then
        if _str == _re_str or _re_str == "*" then
            return true
        end
    elseif _options == "table" then
        if type(_re_str) ~= "table" then return false end
        for i,v in ipairs(_re_str) do
            if v == _str then
                return true
            end
        end
    elseif _options == "in" then --- 用于包含 查找 string.find       
        local from , to = string.find(_str, _re_str)
        --if from ~= nil or (from == 1 and to == 0 ) then
        --当re_str=""时的情况 没有处理
        if from ~= nil then
            return true
        end
    elseif _options == "list" then
        if type(_re_str) ~= "table" then return false end
        local re = _re_str[_str]
        if re == true then
            return true
        end
    elseif _options == "@token@" then
        local a = tostring(token_dict:get(_str))
        if a == _re_str then 
            token_dict:delete(_str) -- 使用一次就删除token
            return true
        end
    elseif _options == "cidr" then
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
        local from, to = ngx.re.find(_str, _re_str, _options)
        if from ~= nil then
            return true,string.sub(_str, from, to)
        end
    end
end

local count_dict = ngx.shared.count_dict

--- 拦截计数
local function set_count_dict(_key)
    if _key == nil then return end
    local key_count = count_dict:get(_key)
    if key_count == nil then 
        count_dict:set(_key,1)
    else
        count_dict:incr(_key,1)
    end
end


local function ngx_find(_str)
    -- str = string.gsub(str,"@ngx_time@",ngx.time())
    -- ngx.re.gsub 效率要比string.gsub要好一点，参考openresty最佳实践
    _str = ngx.re.gsub(_str,"@ngx_localtime@",ngx.localtime())

    -- string.find 字符串 会走jit,所以就没有用ngx模块
    -- 当前情况下，对token仅是全局替换一次，请注意
    if string.find(_str,"@token@") ~= nil then       
        _str = ngx.re.gsub(_str,"@token@",set_token())
    end 
    return _str
end

local function sayHtml_ext(_html,_ty) 
    ngx.header.content_type = "text/html"
    if _html == nil then 
        _html = "_html is nil"
    elseif type(_html) == "table" then
        if _ty == nil then               
            _html = tableTojson(_html)
        else
            _html = tableTostring(_html)
        end
    end
    ngx.say(ngx_find(tostring(_html)))
    ngx.exit(200)
end

local function sayFile(_filename)
    ngx.header.content_type = "text/html"
    --local str = readfile(Config.base.htmlPath..filename)
    local str = readfile(_filename) or "filename error"
    ngx.say(str)
    ngx.exit(200)
end

local function sayLua(_luapath)
    --local re = dofile(Config.base.htmlPath..lua)
    local re = dofile(_luapath)
    return re
end

-- 记录debug日志
-- 更新记录IP 2016年6月7日 22:22:15
local function debug(_filename,_base_msg,_info)
    if _base_msg.config_base.debug_Mod == false then return end --- 判断debug开启状态
    if _filename == nil then
        _filename = "debug.log"
    end
    local filepath = _base_msg.config_base.logPath or "./"
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
    local request_url = _base_msg.request_url
    local url = _base_msg.url
    local agent = _base_msg.agent
    local referer = _base_msg.referer
    local str = string.format([[%s "%s" "%s" [%s] "%s" "%s" "%s" "%s" "%s" "%s"]],remoteIp,host,ip,time,method,status,url,agent,referer,_info)
    
    writefile(filepath,str)
end

--- 请求相关

    --- 获取单个args值
    local function get_argsByName(_name)
        --if _name == nil then return "" end
        --调用时 先判断下nil的情况
        local x = 'arg_'.._name
        local _name = ngx.unescape_uri(ngx.var[x])
        return _name
        -- local args_name = ngx.req.get_uri_args()[_name]
        -- if type(args_name) == "table" then args_name = args_name[1] end
        -- return ngx.unescape_uri(args_name)
    end

    --- 获取所有args参数
    local function get_args()
        return ngx.unescape_uri(ngx.var.query_string)
    end

    --- 获取单个post值
    local function get_postByName(_name)
        --if _name == nil then return "" end
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
optl.guid = guid
optl.set_token = set_token
optl.remath = remath
optl.set_count_dict = set_count_dict
optl.ngx_find = ngx_find

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