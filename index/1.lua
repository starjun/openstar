
-----  自定义lua脚本 by zj -----

local headers = ngx.req.get_headers()
local host = ngx.unescape_uri(headers["Host"])
local url = ngx.unescape_uri(ngx.var.uri)


local token_dict = ngx.shared.token_dict


--- remath(str,re_str,options)
--- 常用二阶匹配规则
local function remath(str,re_str,options)
	if str == nil or re_str == nil or options == nil then return false end
	if options == "" then
		if str == re_str or re_str == "*" then
			return true
		end
	elseif options == "table" then
		if type(re_str) ~= "table" then return false end
		for i,v in ipairs(re_str) do
			if v == str then
				return true
			end
		end
	elseif options == "in" then --- 用于包含 查找 string.find
		local from , to = string.find(str, re_str)
		--if from ~= nil or (from == 1 and to == 0 ) then
		--当re_str=""时的情况 没有处理
		if from ~= nil then
			return true
		end
	elseif options == "list" then
		if type(re_str) ~= "table" then return false end
		local re = re_str[str]
		if re == true then
			return true
		end
	elseif options == "@token@" then
		local a = tostring(token_dict:get(str))
		if a == re_str then 
			token_dict:delete(str) -- 使用一次就删除token
			return true
		end
	else
		local from, to = ngx.re.find(str, re_str, options)
	    if from ~= nil then
	    	return true,string.sub(str, from, to)
	    end
	end
end

--- 匹配 host 和 url
local function host_url_remath(_host,_url)
	if remath(host,_host[1],_host[2]) and remath(url,_url[1],_url[2]) then
		return true
	end
end


local tb_do = {
				host={"*",""},
				url={[[/api/debug]],""}
			}


if host_url_remath(tb_do.host,tb_do.url) then
	ngx.say("ABC.ABC IS ABC")
	return "break"   --- break 表示跳出for循环
else
	return  ---- 否则继续for循环 继续规则判断
end


