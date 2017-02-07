
local optl = require("optl")
local request_guid = ngx.ctx.request_guid
optl.del_token(request_guid)

-- 全局访问计数
local gl_request_count = "global request count"
optl.set_count_dict(gl_request_count)

-- host - uri 计数
