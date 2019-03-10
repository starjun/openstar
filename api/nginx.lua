
----  对nginx 进程操作
-- nginx -t 和 nginx -s reload

local optl = require("optl")
local get_argsByName
if ngx.var.request_method == "POST" then
    get_argsByName = optl.get_postByName
else
    get_argsByName = optl.get_argsByName
end

local _action = get_argsByName("action")
local ngx_path = ngx.config.prefix()

local _code = "ok"
if _action == "reload" then
    local comm_test = ngx_path.."sbin/nginx -t"
    local re = os.execute(comm_test)
    if not re then
        _code = "error"
        optl.sayHtml_ext({code=_code,msg=comm_test})
    end
    local comm = ngx_path.."sbin/nginx -s reload"
    re = os.execute(comm)
    if not re then
        _code = "error"
    end
    optl.sayHtml_ext({code=_code,msg=comm})
else
    local comm = ngx_path.."sbin/nginx -t"
    local re = os.execute(comm)
    if not re then
        _code = "error"
    end
    --local t = io.popen("ls -a")
    --local a = t:read("*all")
    optl.sayHtml_ext({code=_code,msg=comm})
end