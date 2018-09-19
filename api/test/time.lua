local httpdata = {}

httpdata[1] = "ngx.today : "..ngx.today()
httpdata[2] = "ngx.time : "..ngx.time()
httpdata[3] = "ngx.now : "..ngx.now()
httpdata[4] = "ngx.update_time is fuc"
httpdata[5] = "ngx.localtime : "..ngx.localtime()
httpdata[6] = "ngx.utctime : "..ngx.utctime()
httpdata[7] = "ngx.cookie_time(ngx.now()) : "..ngx.cookie_time(ngx.now())
httpdata[8] = "ngx.http_time(ngx.now()) : "..ngx.http_time(ngx.now())
httpdata[9] = "ngx.parse_http_time(ngx.http_time(ngx.now())) : "..ngx.parse_http_time(ngx.http_time(ngx.now()))
local ngx_null = tostring(ngx.null).." [ type: "..type(ngx.null).." ]" or "ngx_null"
httpdata[10] = "ngx.null : "..ngx_null


local cjson_safe = require "cjson.safe"
local json_text = cjson_safe.encode(httpdata)

ngx.say(json_text)
ngx.exit(200)