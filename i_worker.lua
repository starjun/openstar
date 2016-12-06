

if ngx.worker.id() ~= 0 then return end

local timeAt = 5
local handler

-- dict 清空过期内存
local function flush_expired_dict()
	local dict_list = {"token_dict","count_dict","config_dict","host_dict","ip_dict","limit_ip_dict"}
	for i,v in ipairs(dict_list) do
		ngx.shared[v]:flush_expired()
	end
end

handler = function()  
	-- do something
	flush_expired_dict()

	--  
	local ok, err = ngx.timer.at(timeAt, handler)  
	if not ok then  
	  ngx.log(ngx.ERR, "failed to startup handler worker...", err)
	end  
end  
  
handler()