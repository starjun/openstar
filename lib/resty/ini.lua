-- Copyright (C) Dejiang Zhu(doujiang24)


local io_open = io.open
local tonumber = tonumber
local re_match = ngx.re.match
local substr = string.sub


local _M = { _VERSION = "0.01" }

local section_pattern = [[ \A \[ ([^ \[ \] ]+) \] \z ]]
local keyvalue_pattern = [[ \A ( [\w_]+ ) \s* = \s* ( ' [^']* ' | " [^"]* " | \S+ ) (?:\s*)? \z ]]


function _M.parse_file(filename)
    local fp, err = io_open(filename)
    if not fp then
        return nil, "failed to open file: " .. (err or "")
    end

    local data = {}
    local section = "default"

    for line in fp:lines() do
        local m = re_match(line, section_pattern, "jox")
        if m then
            section = m[1]

        else
            local m = re_match(line, keyvalue_pattern, "jox")
            if m then
                if not data[section] then
                    data[section] = {}
                end

                local key, value = m[1], m[2]

                local val = tonumber(value)
                if val then
                    -- do nothing

                elseif value == "true" then
                    val = true

                elseif value == "false" then
                    val = false

                elseif substr(value, 1, 1) == '"' or substr(value, 1, 1) == "'" then
                    val = substr(value, 2, -2)

                else
                    val = value
                end

                data[section][key] = val;
            end
        end
    end

    fp:close()

    return data
end


return _M
