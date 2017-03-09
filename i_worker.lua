

if ngx.worker.id() ~= 0 then return end

local handler

-- dict 清空过期内存
local function flush_expired_dict()
	local dict_list = {"token_dict","count_dict","config_dict","host_dict","ip_dict","limit_ip_dict"}
	for i,v in ipairs(dict_list) do
		ngx.shared[v]:flush_expired()
	end
end

-- 拉取数据
local function pull_redisConfig()
	
end

-- 推送统计计数等
local function push_count_dict()
	
end

-- 保存到本机文件
local function save_configFile()
	
end

handler = function()
	-- do something
	local config_dict = ngx.shared.config_dict
	local config_base = cjson_safe.decode(config_dict:get("base")) or {}
	local timeAt = config_base.autoSync.timeAt or 5

	-- 如果 auto Sync 开启 就定时从redis 拉取配置并推送一些计数
	if config_base.autoSync.state == "on" then

	end

	--清空过期内存
	ngx.thread.spawn(flush_expired_dict)

	--
	local ok, err = ngx.timer.at(timeAt, handler)
	if not ok then
		ngx.log(ngx.ERR, "failed to startup handler worker...", err)
	end
end

local ok, err = ngx.timer.at(0, handler)
if not ok then
	ngx.log(ngx.ERR, "failed to startup handler worker...", err)
end