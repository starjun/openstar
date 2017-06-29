
local ngx_var = ngx.var
local ngx_unescape_uri = ngx.unescape_uri
local next_ctx = ngx.ctx.next_ctx or {}

if type(next_ctx.replace_Mod) ~= "table" then
	return
end

local token_dict = ngx.shared.token_dict
local optl = require("optl")

-- 返回内容的替换使用 ngx.re.gsub 后续会更新用户可指定替换函数(如 ngx.re.sub)
local function ngx_2(reps,str_all)
	for _,v in ipairs(reps) do
		local tmp3 = optl.ngx_find(v[3])
		if v[2] == "" then
			str_all = ngx.re.gsub(str_all,v[1],tmp3)
		else
			str_all = ngx.re.gsub(str_all,v[1],tmp3,v[2])
		end		
	end
	ngx.arg[1] = str_all
	token_dict:delete(token_tmp)
end

-- ngx.ctx.next_ctx.request_guid 一定要保证存在
local token_tmp = next_ctx.request_guid

if ngx.arg[1] ~= '' then -- 请求正常
	local chunk = token_dict:get(token_tmp)
	if chunk == nil then
		chunk = ngx.arg[1]
		token_dict:set(token_tmp,chunk,15)
	else
		chunk = chunk..ngx.arg[1]
		token_dict:set(token_tmp,chunk,15)
	end
end

local tmp_replace_mod = next_ctx.replace_Mod
if ngx.arg[2] then
	ngx_2(tmp_replace_mod.replace_list,token_dict:get(token_tmp))
else
	ngx.arg[1] = nil
end