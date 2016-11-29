
local optl = require("optl")
local request_guid = ngx.ctx.request_guid
optl.del_token(request_guid)

