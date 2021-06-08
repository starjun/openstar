local type          = type
local pairs         = pairs
local ipairs        = ipairs
local tonumber      = tonumber
local tostring      = tostring
local getmetatable  = getmetatable
local setmetatable  = setmetatable
local cjson_safe    = require "cjson.safe"
local JSON          = require("resty.JSON")
local shell         = require "resty.shell"
local clone         = require "table.clone"
local ipmatcher     = require "resty.ipmatcher"
local string_gmatch = string.gmatch
local string_sub    = string.sub
local string_find   = string.find
local string_lower  = string.lower
local string_format = string.format
local ngx_re_find   = ngx.re.find
local table_remove  = table.remove
local table_concat  = table.concat
local table_insert  = table.insert
local math_floor    = math.floor
local io_popen      = io.popen
local io_open       = io.open

local _M            = { _VERSION = 0.2 }

-- 去前后空格
local function trim(s)
    -- 去前后空格
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end
_M.trim = trim

-- 快速判断 table 类型 （数组字典）
local function isArrayTable(t)
    if type(t) ~= "table" then
        return false
    end
    local n = #t
    for i , v in pairs(t) do
        if type(i) ~= "number" then
            return false
        end
        if math_floor(i) < i or i < 0 or i > n then
            return false
        end
    end
    return true
end
_M.isArrayTable = isArrayTable

-- 判断 传入的 _value 是否在 list 类型的 _tb 中
local function isInArrayTb(_value , _tb)
    if type(_tb) ~= "table" then
        return false
    end
    for _ , v in ipairs(_tb) do
        if v == _value then
            return true
        end
    end
end
_M.isInArrayTb = isInArrayTb

-- split 分割函数
-- 新版openresty lua-resty-core 支持 split 函数
-- https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/re.md#split
local function split(inputstr , sep)
    sep     = sep or "%s"
    local t , i = {} , 1
    for str in string_gmatch(inputstr , "([^" .. sep .. "]+)") do
        t[i] = str
        i    = i + 1
    end
    return t
end
_M.split = split

-- ["false","true"] 转 boolean
-- 只有 _str == 'true' 为 真，其余都为 假
local function strToBoolean(_str)
    if string_lower(_str) == "true" then
        return true
    else
        return false
    end
end
_M.strToBoolean = strToBoolean

-- 判断传入的 str 是否为一个合法的 点分ip
local function isIp(_str_ip)
    local re_ip     = "^(1\\d{2}|2[0-4]\\d|25[0-5]|[1-9]\\d|[1-9])\\."
    re_ip           = re_ip .. "(1\\d{2}|2[0-4]\\d|25[0-5]|[1-9]\\d|\\d)\\."
    re_ip           = re_ip .. "(1\\d{2}|2[0-4]\\d|25[0-5]|[1-9]\\d|\\d)\\."
    re_ip           = re_ip .. "(1\\d{2}|2[0-4]\\d|25[0-5]|[1-9]\\d|\\d)$"
    local from , to = ngx_re_find(_str_ip , re_ip , "jios")
    if from then
        return true
    end
end
_M.isIp = isIp

-- 判断传入的 str 是否是一个合法的 域名
local function isHost(_str_host)
    if isIp(_str_host) then
        return true
    end
    local tmp = { "localhost5460", "localhost" }
    if isInArrayTb(_str_host , tmp) then
        return true
    end
    local re_host   = "^(?=^.{3,255}$)[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+$"
    local from , to = ngx_re_find(_str_host , re_host , "jios")
    if from then
        return true
    end
end
_M.isHost = isHost

-- 判断传入是 str 是否是一个合法的 cidr
local function isCidr(_str)
    local arr = split(_str,'/')
    if arr[1] and isIp(arr[1]) then
        local mask = tonumber(arr[2])
        if mask and (mask >=0 and mask <=32)then
            return true
        end
    end
end
_M.isCidr = isCidr

-- 判断是否是内网IP
local _matip = ipmatcher.new({"10.0.0.0/8","172.16.0.0/12","192.168.0.0/16"})
local function isLocalip( _ip )
    -- 封装成个函数
    return _matip:match( _ip )
end
_M.isLocalip = isLocalip

-- 计算传入的 table 的count
local function getTableCount(t)
    local count = 0
    if isArrayTable(t) then
        count = #t
    else
        for _ , v in pairs(t) do
            count = count + 1
        end
    end
    return count
end
_M.getTableCount = getTableCount

-- 从table中 获取key的值（支持@标记 获取子节点的值）
-- args@a
local function get_keyInTable(_tb , _k , _tag)
    _tag        = _tag or "@"
    local tmp_v = _tb[_k]
    if tmp_v then
        return tmp_v
    end
    local listKey = split(_k , _tag)
    if #listKey == 1 then
        local tmp_k = tonumber(_k) or _k
        return _tb[tmp_k]
    else
        local tmp_k = tonumber(listKey[1]) or listKey[1]
        local _tmp  = _tb[tmp_k]
        if type(_tmp) == "table" then
            -- 将后续的key进行拼接
            table_remove(listKey , 1)
            local newKey = table_concat(listKey , _tag)
            return get_keyInTable(_tmp , newKey)
        else
            return _tmp
        end
    end
end
_M.get_keyInTable = get_keyInTable

-- 递归 对比两个 table 相等返回 true
local function table_compare(t1 , t2 , ignore_mt)
    local ty1 = type(t1)
    local ty2 = type(t2)
    if ty1 ~= ty2 then
        return false
    end
    -- non-table types can be directly compared
    if ty1 ~= 'table' and ty2 ~= 'table' then
        return t1 == t2
    end
    -- as well as tables which have the metamethod __eq
    local mt = getmetatable(t1)
    if not ignore_mt and mt and mt.__eq then
        return t1 == t2
    end
    for k1 , v1 in pairs(t1) do
        local v2 = t2[k1]
        if v2 == nil or not table_compare(v1 , v2) then
            return false
        end
    end
    for k2 , v2 in pairs(t2) do
        local v1 = t1[k2]
        if v1 == nil or not table_compare(v1 , v2) then
            return false
        end
    end
    return true
end
_M.table_compare = table_compare

-- table 深 copy (ismt 控制元表copy)
local function table_copy(orig , ismt)
    local copy
    if type(orig) == "table" then
        if ismt then
            copy = {}
            for orig_key , orig_value in next , orig , nil do
                copy[table_copy(orig_key)] = table_copy(orig_value)
            end
            setmetatable(copy , table_copy(getmetatable(orig)))
        else
            copy = clone(orig)
        end
    else
        copy = orig
    end
    return copy
end
_M.table_copy = table_copy

-- 反转 table
local function reverseTable(tab)
    local tmp = {}
    for i = 1, #tab do
        local key = #tab
        tmp[i] = table.remove(tab)
    end
    return tmp
end
_M.reverseTable = reverseTable

local function stringStarts(String , Start)
    return string_sub(String , 1 , #Start) == Start
end
_M.stringStarts = stringStarts

local function stringEnds(String , End)
    return string_sub(String , -#End) == End
end
_M.stringEnds = stringEnds

-- 包含 查找 string_find
local function stringIn(String , in_str)
    if String == "" then
        return false
    end
    local from , to = string_find(String , in_str , 1 , true)
    if from ~= nil and to ~= 0 then
        --当_re_str=""时的情况 已处理
        return true
    end
end
_M.stringIn = stringIn

--- pathJoin
local function pathJoin(path1 , path2)
    -- 把两个路径拼接到一起，例如 ‘abc’ 和 ‘def’ 拼接为 ‘abc/def’
    if string_sub(path1 , -1 , -1) ~= '/' then
        return string_format('%s/%s' , path1 , path2)
    else
        return string_format('%s%s' , path1 , path2)
    end
end
_M.pathJoin = pathJoin

-- 判断给定路径的文件或则会目录是否存在
-- 存在 true
local function fileOrdirExist(path)
    local file = io_open(path , 'rb')
    if file then
        file:close()
    end
    return file ~= nil
end
_M.fileOrdirExist = fileOrdirExist

local function getFileByDir(dir , pre , suf)
    -- 罗列目录下的所有文件名称，可以用pre和suf来进行前缀/后缀过滤
    -- 返回格式eg： name1,name2
    if not fileOrdirExist(dir) then
        return nil , 'file or dir not existed'
    end

    local _r  = io_popen("ls " .. dir)
    local _tb = split(_r:read("*all"))

    if pre ~= nil then
        local _rb = {}
        for _ , _item in pairs(_tb) do
            if stringStarts(_item , pre) == true then
                table_insert(_rb , _item)
            end
        end
        _tb = _rb
    end

    if suf ~= nil then
        local _rb = {}
        for _ , _item in pairs(_tb) do
            if stringEnds(_item , suf) == true then
                table_insert(_rb , _item)
            end
        end
        _tb = _rb
    end

    return _tb
end
_M.getFileByDir = getFileByDir

--- 读取文件（全部读取/按行读取）默认 全部读取
local function readfile(_filepath , _ty)
    local fd , err = io_open(_filepath , "r")
    if not fd then
        return
    end
    if not _ty then
        local str = fd:read("*a") --- 全部内容读取
        fd:close()
        return str
    else
        local line_s = {}
        for line in fd:lines() do
            table_insert(line_s , line)
        end
        fd:close()
        return line_s
    end
end
_M.readfile = readfile

-- 默认写文件错误时，会将错误信息和_msg数据使用ngx.log写到错误日志中。
-- ngx.log对写入的信息进行了大小控制，一些大数据情况理论上不用担心
-- 自己调用时，_msg的内容大小需要自己进行控制
local function writefile(_filepath , _msg , _ty)
    _ty            = _ty or "a+"
    -- w+ 覆盖 写文件方式默认是追加方式
    local fd , err = io_open(_filepath , _ty)
    if not fd then
        ngx.log(ngx.ERR , "writefile msg : " .. tostring(_msg) , err)
        return false , tostring(err)
    end -- 文件读取错误返回
    fd:write(tostring(_msg))
    fd:flush()
    fd:close()
    return true
end
_M.writefile = writefile

-- table转成json字符串
local function tableTojsonStr(_obj,_pretty,_empty_tb)
    if _pretty then
        return JSON:encode_pretty(_obj)
    else
        if not _empty_tb then
            cjson_safe.encode_empty_table_as_object(false)
        end
        return cjson_safe.encode(_obj)
    end
end
_M.tableTojsonStr = tableTojsonStr

-- 字符串转成序列化后的json同时也可当table类型
local function stringTojson(_obj)
    local json = cjson_safe.decode(_obj)
    return json
end
_M.stringTojson = stringTojson

local function loadjson(_path_name)
    local x    = readfile(_path_name)
    local json = stringTojson(x) or {}
    return json
end
_M.loadjson = loadjson

-- base_msg 获取指定 key
-- eg key = $ip ,...
-- scheme uri remoteIp ip serverIp http_host server_name host method referer
-- useragent cookie request_uri query_string http_content_type header_data args_data posts_data posts_all
-- args posts headers
-- post_form
-- eg:args@a [取get参数为a的值] posts@a [取普通 form post时参数为a的值]
local function get_base_msg_by_key(_basemsg,_key)
    if _key == nil then return "" end
    if stringStarts(_key,"$") then
        local real_key = string_sub(_key,2,#_key)
        if real_key == "args" or real_key == "posts" or real_key == "headers" or real_key == "post_form" then
            -- 返回整个 table
            return _basemsg[real_key]
        end
        local tmp = get_keyInTable(_basemsg,real_key)
        if type(tmp) == "table" then
            return tmp[1]
        else
            return tmp
        end
    else
        return _key
    end
end
_M.get_base_msg_by_key = get_base_msg_by_key

local function supCmd(_str)
    local t = io_popen(_str)
    return t:read("*all")
end
_M.supCmd = supCmd

local function OsExe(_str)
    local re,err = os.execute(_str)
    local msg = string.format("_str : %s  re : %s err : %s",_str,re,err)
    return re,err
end
_M.OsExe = OsExe

local function Doshell(_str)
    local stdin = ""
    local timeout = 3000  -- ms
    local max_size = 40960  -- byte
    local ok, stdout, stderr, reason, status =
        shell.run(_str, stdin, timeout, max_size)
    local msg = string.format("ok : %s  stdout : %s stderr : %s reason: %s status: %s",ok,stdout,stderr,reason,status)
    if not ok then
        return false,msg
    else
        return true,msg
    end
end
_M.Doshell = Doshell

return _M