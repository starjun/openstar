
----  对nginx 进程操作
-- nginx -t 和 nginx -s reload

local optl = require("optl")
local get_argsByName = optl.get_argsByName

local _action = get_argsByName("action")
local ngx_path = ngx.config.prefix()

local _code = "ok"
if _action == "reload" then
    local comm = ngx_path.."sbin/nginx -s reload"
    local re = os.execute(comm)
    if re ~= 0 then
        _code = "error"
    end
    optl.sayHtml_ext({code=_code,msg=re,action=_action})
else
    local comm = ngx_path.."sbin/nginx -t"
    local re = os.execute(comm)
    if re ~= 0 then
        _code = "error"
    end
    --local t = io.popen("ls -a")
    --local a = t:read("*all")
    optl.sayHtml_ext({code=_code,msg=re,action="nginx -t"})
end