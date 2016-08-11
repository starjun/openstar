

local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end
local _action = get_argByName("action")
local _key = get_argByName("key")
local _dict = get_argByName("dict")




local tmpdict = ngx.shared[_dict]
if tmpdict == nil then sayHtml_ext("dict is nil") end

if _action == "get" then
	
	if _key == "count_key" then
		local _tb = tmpdict:get_keys(0)
		sayHtml_ext(table.getn(_tb))
	elseif _key == "all_key" then
		local _tb,tb_all = tmpdict:get_keys(0),{}
		for i,v in ipairs(_tb) do
			tb_all[v] = tmpdict:get(v)
		end
		sayHtml_ext(tb_all)
	elseif _key == "" then
		local _tb = tmpdict:get_keys(1024)
		sayHtml_ext(_tb)
	else
		sayHtml_ext(tmpdict:get(_key))
	end

elseif _action == "set" then

	if _token == "" then
		local re = set_token()
		sayHtml_ext({_token=re})
	else
		local re = set_token(_token)
		sayHtml_ext({_token = re})
	end

else

end