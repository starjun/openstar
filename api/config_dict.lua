

local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end

local _action = get_argByName("action")
local _key = get_argByName("key")
local _token = get_argByName("token")
local tmpdict = ngx.shared.config_dict

if _action == "get" then
	


elseif _action == "set" then


else

end