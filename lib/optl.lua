
--- 文件读写
local function readfile(_filepath)
    local fd = assert(io.open(_filepath,"r"),"readfile io.open error")
    if fd == nil then return end
    local str = fd:read("*a") --- 全部内容读取
    fd:close()
    return str
end

local function writefile(_filepath,_msg,_ty)
    _ty = nil or "a+"
    -- w+ 覆盖
    local fd = assert(io.open(_filepath,_ty),"writefile io.open error")
    if fd == nil then return end -- 文件读取错误返回
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

-- guid() 局部函数用于生成唯一随机字符串
local function guid()
    local random = require "resty-random"
    return string.format('%s-%s',
        random.token(10),
        random.token(10)
    )
end

-- 设置token 并缓存3分钟
local function set_token(_token)
    _token = _token or guid()
    local token_dict = ngx.shared.token_dict;
    if token_dict:get(_token) == nil then 
        token_dict:set(_token,true,3*60)  --- -- 缓存3分钟 非重复插入
        return _token
    else
        return set_token()
    end 
end

--- ngx_find
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

-- sayHtml_ext(fileorhtml,ty)
local function sayHtml_ext(_html,_ty) 
    ngx.header.content_type = "text/html"
    if _html == nil then 
        _html = "_html is nil"
    elseif type(_html) == "table" then
        if _ty == nil then               
            _html = tableTojson(_html)
        else
            _html = tableToString(_html)
        end
    end
    ngx.say(ngx_find(_html))
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
    --debug("sayLua  init re :"..tostring( re ))
    return re
end

-- debug(msg,filename) 记录debug日志
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
    local agent = _base_msg.agent
    local referer = _base_msg.referer
    local str = string.format([[%s "%s" "%s" [%s] "%s" "%s" "%s" "%s" "%s" "%s"]],remoteIp,host,ip,time,method,status,request_url,agent,referer,_info)
    
    writefile(filepath,str)
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

optl.set_token = set_token
optl.ngx_find = ngx_find

--- say相关
optl.sayHtml_ext = sayHtml_ext
optl.sayFile = sayFile
optl.sayLua = sayLua

--- log 相关
optl.debug = debug


return optl