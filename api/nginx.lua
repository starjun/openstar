local function get_argByName(name)
    local x = 'arg_'..name
    local _name = ngx.unescape_uri(ngx.var[x])
    return _name
end

local _action = get_argByName("action")
local ngx_path = ngx.config.prefix()
if _action == "reload" then
    local comm = ngx_path.."sbin/nginx -s reload"
    ngx.say(os.execute(comm))
else
    local comm = ngx_path.."sbin/nginx -t"
    local re = os.execute(comm)
    --local t = io.popen("ls -a")
    --local a = t:read("*all")
    ngx.say(re)
end