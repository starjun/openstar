

local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end

local _action = get_argByName("action")
local _name = get_argByName("name")
local config_dict = ngx.shared.config_dict
local baseDir = config_dict:get("baseDir")
local filepath = baseDir.."conf_json/"



if _action == "save" then
	local _tb = _G[_name]
	if type(_tb) == "table" then
		local _msg = tableTojson(_tb)
		writefile(filepath.._name.."bak.json",_msg,"w+")
		sayHtml_ext(_msg)
	elseif type(_tb) == "string" then
		writefile(filepath.._name.."bak.json",_tb,"w+")
		sayHtml_ext(_msg)
	else
		sayHtml_ext({})
	end
elseif _action =="load" then

	loadConfig()

else
    sayHtml_ext({action="error"})
end


