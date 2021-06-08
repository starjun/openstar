
local function t_split(str, pat)
    local t = {}  -- NOTE: use {n = 0} in Lua-5.0
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(t,cap)
        end
        last_end = e+1
        s, e, cap = str:find(fpat, last_end)
    end

    if last_end <= #str then
        cap = str:sub(last_end)
        table.insert(t, cap)
    end
    return t
end

-- Define a 32-bit structure.
local data_bit = {}
for i=1, 32 do
    data_bit[i] = 2^(32-i)
end

local api = {}

-- turn ip to number.
function api.ip_2_number(data)
    local split_data = t_split(data, "%.")
    local res = 0
    local power = 2^8
    for k,v in pairs(split_data) do
        res = res + tonumber(v) * power ^ (4 - tonumber(k))
    end
    return res
end

-- turn decimal to binary
function api.decimal_2_binary(data)
    local ret = {}
    for i=1, 32 do
        if data >= data_bit[i] then
            ret[i] = 1
            data = data - data_bit[i]
        else
            ret[i] = 0
        end
    end
    return ret
end

-- turn binary to decimal.
function api.binary_2_decimal(data)
    local res = 0
    for i = 1, 32 do
        if data[i] == 1 then
            res = res + 2^(32-i)
        end
    end
    return res
end

-- construct a netmask by length.
function api.netmask(length)
    local res = {}
    for i=1, 32 do
        if i <= length then
            res[i] = 1
        else
            res[i] = 0
        end
    end

    return res
end

function api.xor(binary_net, binary_ip)
    local data = {}
    for i=1, 32 do
        data[i] = binary_net[i] * binary_ip[i]
    end
    return data
end

function api.get_last_address(binary_first, length)
    local data = {}
    for i=1, 32 do
        if i <= length then
            data[i] = binary_first[i]
        else
            data[i] = 1
        end
    end
    return data
end

-- get the first and last address of cidr.
function api.parse_cidr(cidr)

    local ip = cidr:match("(.+)/")
    local length = tonumber(cidr:match("/(.+)"))
    -- Turn netmask to a 32 bit binary.
    local binary_netmask = api.netmask(length)

    -- Turn ip to a 32 bit binary.
    local decimal_ip = api.ip_2_number(ip)
    local binary_ip = api.decimal_2_binary(decimal_ip)

    -- Get the frist and last address of binary type and it is also the network address.
    local first_address = api.xor(binary_netmask, binary_ip)
    local last_address = api.get_last_address(first_address, length)

    -- Return the type of number of first and last address.
    local first_address = api.binary_2_decimal(first_address)
    local last_address = api.binary_2_decimal(last_address)

    return first_address, last_address
end

return api
