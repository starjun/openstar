
ngx.say("test api error")
do return end --- 使用dict 暂时停止table相关API

local function get_argByName(name)
	local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end

local random = require "resty-random"

local mod = get_argByName("mod")
local count = tonumber(get_argByName("count"))

if type(count) ~= "number" then sayHtml_ext({code="count_error"}) return end


if mod == "realIpFrom_Mod" then

	local _tmptb =  _G["realIpFrom_Mod"]

	local value = stringTojson([[{"ips":["111.206.199.57"],"realipset":"CDN-R-IP"}]])
	for i=1,count do
		_tmptb[random.token(17)]=value
	end
	_tmptb["10.0.0.4"] = stringTojson([[{"ips":["10.0.0.5"],"realipset":"x-for-f"}]])

	local cnt = 0
	for k in pairs(_tmptb) do
		cnt=cnt+1
	end

	sayHtml_ext({count=cnt})

elseif mod == "ip_Mod" then

	local tmpdict = ngx.shared.ip_dict
	local re = tmpdict:flush_all()
	local re1 = tmpdict:flush_expired(0)
	local _count = tonumber(get_argByName("count")) or 0
	for i=1,_count do
		tmpdict:safe_set(i,random.token(17),0)
	end
	tmpdict:safe_set("10.0.0.5","allow",0)
	sayHtml_ext({"10.0.0.5",tmpdict:get("10.0.0.5")})

elseif mod == "app_Mod" then

	local _tmptb =  _G["app_Mod"]

	for i=1,count do
		_tmptb[i]= stringTojson([[{"state":"on","action":["rehtml"],"rehtml":"hi~!","hostname":["101.200.122.200",""],"url":["^/]]..random.token(6)..[[\\.do$","jio"]}]])
	end
	_tmptb[count+1] = stringTojson([[{"state":"on","action":["rehtml"],"rehtml":"hi~!","hostname":["101.200.122.200",""],"url":["^/static\\.do$","jio"]}]])

	local cnt = 0
	for k in pairs(_tmptb) do
		cnt=cnt+1
	end

	sayHtml_ext({count=cnt})

elseif mod == "host_method_Mod" then

	local _tmptb =  _G["host_method_Mod"]

	for i=1,count do
		_tmptb[i]= stringTojson([=[{"state":"on","method":[["GET","POST"],"table"],"hostname":[["www.]=]..random.token(5)..[=[.com"],""]}]=])
	end
	_tmptb[count+1] = stringTojson([[{"state":"on","method":[["GET","POST"],"table"],"hostname":[["10.0.0.4"],""]}]])

	local cnt = 0
	for k in pairs(_tmptb) do
		cnt=cnt+1
	end

	sayHtml_ext({count=cnt})

elseif mod == "header_Mod" then

	local _tmptb =  _G["header_Mod"]

	for i=1,count do
		_tmptb[i]= stringTojson([[{"state":"on","url":["*",""],"hostname":["*",""],"header":["]]..random.token(10)..[[","*",""]}]])
	end
	_tmptb[count+1] = stringTojson([[{"state":"on","url":["*",""],"hostname":["*",""],"header":["Acunetix_Aspect","*",""]}]])

	local cnt = 0
	for k in pairs(_tmptb) do
		cnt=cnt+1
	end

	sayHtml_ext({count=cnt})

elseif mod == "referer_Mod" then

	local _tmptb =  _G["referer_Mod"]

	for i=1,count do
		_tmptb[i]= stringTojson([[{"state":"on","url":["^/abc.do$","jio"],"hostname":["pass.]]..random.token(6)..[[.com",""],"referer":["^.*/(www\\.hao123\\.com|www3\\.hao123\\.com)$","jio"],"action":"next"}]])
	end
	_tmptb[count+1] = stringTojson([[{"state":"on","url":["\\.(gif|jpg|png|jpeg|bmp|ico|txt)$","jio"],"hostname":["101.200.122.200",""],"referer":["*",""],"action":"allow"}]])

	local cnt = 0
	for k in pairs(_tmptb) do
		cnt=cnt+1
	end

	sayHtml_ext({count=cnt})

elseif mod == "useragent_Mod" then

	local _tmptb =  _G["useragent_Mod"]

	for i=1,count do
		_tmptb[i]= stringTojson([[{"state":"on","useragent":["HTTrack|harvest|audit|dirbuster|pangolin|nmap|sqln|-scan|hydra|Parser|libwww|BBBike|sqlmap|w3af|owasp|Nikto|fimap|havij|PycURL|zmeu|BabyKrokodil|netsparker|httperf|bench","jio"],"hostname":["www.]]..random.token(5)..[[.com",""]}]])
	end
	_tmptb[count+1] = stringTojson([[{"state":"on","useragent":["HTTrack|harvest|audit|dirbuster|pangolin|nmap|sqln|-scan|hydra|Parser|libwww|BBBike|sqlmap|w3af|owasp|Nikto|fimap|havij|PycURL|zmeu|BabyKrokodil|netsparker|httperf|bench","jio"],"hostname":["*",""]}]])

	local cnt = 0
	for k in pairs(_tmptb) do
		cnt=cnt+1
	end

	sayHtml_ext({count=cnt})

elseif mod == "cookie_Mod" then

	local _tmptb =  _G["cookie_Mod"]

	for i=1,count do
		_tmptb[i]= stringTojson([[{"state":"on","hostname":["*",""],"cookie":["]]..random.token(5)..[[","jio"],"action":"deny"}]])
	end
	_tmptb[count+1] = stringTojson([[{"state":"on","hostname":["*",""],"cookie":["select.+(from|limit)","jio"],"action":"deny"}]])

	local cnt = 0
	for k in pairs(_tmptb) do
		cnt=cnt+1
	end

	sayHtml_ext({count=cnt})

elseif mod == "url_Mod" then

	local _tmptb =  _G["url_Mod"]

	for i=1,count do
		_tmptb[i]= stringTojson([[{"state":"on","hostname":["*",""],"url":["\\.(]]..random.token(5)..[[)","jio"],"action":"deny"}]])
	end
	_tmptb[count+1] = stringTojson([[{"state":"on","hostname":["*",""],"url":["\\.(svn|git|htaccess|bash_history)","jio"],"action":"deny"}]])

	local cnt = 0
	for k in pairs(_tmptb) do
		cnt=cnt+1
	end

	sayHtml_ext({count=cnt})

elseif mod == "args_Mod" then

	local _tmptb =  _G["args_Mod"]

	for i=1,count do
		_tmptb[i]= stringTojson([[{"state":"on","hostname":["*",""],"args":["]]..random.token(5)..[[","jio"],"action":"deny"}]])
	end
	_tmptb[count+1] = stringTojson([[{"state":"on","hostname":["*",""],"args":["select.+(from|limit)","jio"],"action":"deny"}]])

	local cnt = 0
	for k in pairs(_tmptb) do
		cnt=cnt+1
	end

	sayHtml_ext({count=cnt})

elseif mod == "post_Mod" then

	local _tmptb =  _G["post_Mod"]

	for i=1,count do
		_tmptb[i]= stringTojson([[{"state":"on","hostname":["*",""],"post":["]]..random.token(5)..[[","jio"],"action":"deny"}]])
	end
	_tmptb[count+1] = stringTojson([[{"state":"on","hostname":["*",""],"post":["select.+(from|limit)","jio"],"action":"deny"}]])

	local cnt = 0
	for k in pairs(_tmptb) do
		cnt=cnt+1
	end

	sayHtml_ext({count=cnt})

elseif mod == "network_Mod" then

	local _tmptb =  _G["network_Mod"]

	for i=1,count do
		_tmptb[i]= stringTojson([[{"state":"on","network":{"maxReqs":30,"pTime":10,"blacktime":600},"hostname":[["101.200.122.200","127.0.0.1"],"table"],"url":["\\]]..random.token(5)..[[\\.do",""]}]])
	end
	_tmptb[count+1] = stringTojson([[{"state":"on","network":{"maxReqs":30,"pTime":10,"blacktime":600},"hostname":[["10.0.0.4","127.0.0.1"],"table"],"url":["*",""]}]])

	local cnt = 0
	for k in pairs(_tmptb) do
		cnt=cnt+1
	end

	sayHtml_ext({count=cnt})

elseif mod == "replace_Mod" then

	local _tmptb =  _G["replace_Mod"]

	for i=1,count do
		_tmptb[i]= stringTojson([=[{"state":"on","url":["^/]=]..random.token(5)..[=[$","jio"],"hostname":["passport.game.com",""],"replace_list":[["fuck","","FUCK"],["hello","","HELLO"],["lzcaptcha\\?key='\\s*\\+ key","jio","lzcaptcha?keY='+key+'&keytoken=@token@'"]]}]=])
	end
	_tmptb[count+1] = stringTojson([=[{"state":"on","url":["^/$","jio"],"hostname":["10.0.0.4",""],"replace_list":[["你好","","FUCK"],["hello","","Hello123"],["lzcaptcha\\?key='\\s*\\+ key","jio","lzcaptcha?keY='+key+'&keytoken=@token@'"]]}]=])

	local cnt = 0
	for k in pairs(_tmptb) do
		cnt=cnt+1
	end

	sayHtml_ext({count=cnt})

else

	sayHtml_ext({code="error_mod"})

end