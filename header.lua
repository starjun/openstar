
--if ngx.req.is_internal() then return end
local ngx_var = ngx.var
local next_ctx = ngx.ctx.next_ctx or {}
local type = type

if type(next_ctx.replace_Mod) == "table" then
    ngx.header["content-length"] = nil
end

if next_ctx.http_code then
    ngx.status = next_ctx.http_code
end