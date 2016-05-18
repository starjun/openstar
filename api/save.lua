

local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end

local _type = get_argByName("type")
local _name = get_argByName("name")

local filepath = baseDir.."conf_json/"


if _type == "dict" then

	local _dict = ngx.shared[_name]
	--sayHtml_ext({dict=type(_dict),name=_name,type=_type,file=_file})
	if _dict ~= nil then
		local _tb,tb_all = _dict:get_keys(0),{}
		for i,v in ipairs(_tb) do
			tb_all[v] = _dict:get(v)
		end
		local _msg = tableTojson(tb_all)
		writefile(filepath.._name.."bak.json",_msg,"w+")
		sayHtml_ext(_msg)
	else
		sayHtml_ext({dict=_dict})
	end

elseif _type == "table" then

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

else
	sayHtml_ext("type is null")
end

