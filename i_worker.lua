

if ngx.worker.id() ~= 0 then return end


local cjson_safe = require "cjson.safe"
local optl = require("optl")
local handler
local config_base

-- dict 清空过期内存
local function flush_expired_dict()
	local dict_list = {"token_dict","count_dict","config_dict","host_dict","ip_dict","limit_ip_dict"}
	for i,v in ipairs(dict_list) do
		ngx.shared[v]:flush_expired()
	end
end

-- 拉取config_dict配置数据
local function pull_redisConfig()
	local http = require "resty.http"
	local httpc = http.new()

	-- The generic form gives us more control. We must connect manually.
	httpc:set_timeout(500)
	httpc:connect("127.0.0.1", 5460)

	-- And request using a path, rather than a full URI.
	-- 调试阶段debug=yes 否则 应该是 no
	local res, err = httpc:request{
	  path = "/api/redis?action=pull&key=all_dict&debug=yes",
	  headers = {
	      ["Host"] = "127.0.0.1:5460",
	  },
	}

	if not res then
		ngx.log(ngx.ERR, "failed to pull_redisConfig request: ", err)
		return
	else
		--optl.writefile(config_base.logPath.."i_worker.log","pull_redisConfig: "..optl.tableTojson(res))
		return true
	end

end

-- 推送config_dict、host_dict、count_dict到redis
local function push_Master()
	local http = require "resty.http"
	local httpc = http.new()

	-- The generic form gives us more control. We must connect manually.
	httpc:set_timeout(500)
	httpc:connect("127.0.0.1", 5460)

	-- And request using a path, rather than a full URI.
	-- 目前是调试阶段 denug=yes ,否则就是 no
	local res, err = httpc:request{
	  path = "/api/redis?action=push&key=all_dict&debug=yes",
	  headers = {
	      ["Host"] = "127.0.0.1:5460",
	  },
	}

	if not res then
		ngx.log(ngx.ERR, "failed to push_Master request: ", err)
		return
	else
		--optl.writefile(config_base.logPath.."i_worker.log","push_Master: "..optl.tableTojson(res))
		return true
	end
end

-- 推送count_dict统计、计数等
local function push_count_dict()
	local http = require "resty.http"
	local httpc = http.new()

	-- The generic form gives us more control. We must connect manually.
	httpc:set_timeout(500)
	httpc:connect("127.0.0.1", 5460)

	-- And request using a path, rather than a full URI.
	-- 目前是调试阶段 denug=yes ,否则就是 no
	local res, err = httpc:request{
	  path = "/api/redis?action=push&key=count_dict&debug=yes",
	  headers = {
	      ["Host"] = "127.0.0.1:5460",
	  },
	}

	if not res then
		ngx.log(ngx.ERR, "failed to push_count_dict request: ", err)
		return
	else
		--optl.writefile(config_base.logPath.."i_worker.log","push_count_dict: "..optl.tableTojson(res))
		return true
	end

end

-- 保存config_dict、host_dict到本机文件
local function save_configFile()
	local http = require "resty.http"
	local httpc = http.new()

	-- The generic form gives us more control. We must connect manually.
	httpc:set_timeout(500)
	httpc:connect("127.0.0.1", 5460)

	-- And request using a path, rather than a full URI.
	-- 调试阶段debug=yes 否则应该是 no
	local res, err = httpc:request{
	  path = "/api/config?action=save&mod=all_mod&debug=yes",
	  headers = {
	      ["Host"] = "127.0.0.1:5460",
	  },
	}

	if not res then
		ngx.log(ngx.ERR, "failed to save_configFile request: ", err)
		return
	else
		--optl.writefile(config_base.logPath.."i_worker.log","save_configFile: "..optl.tableTojson(res))
		return true
	end

end

handler = function()
	-- do something
	local config_dict = ngx.shared.config_dict
	config_base = cjson_safe.decode(config_dict:get("base")) or {}
	local timeAt = config_base.autoSync.timeAt or 5

	-- 如果 auto Sync 开启 就定时从redis 拉取配置并推送一些计数
	if config_base.autoSync.state == "Master" then
		config_base.autoSync.state = "Slave"
		if config_dict:replace("base",cjson_safe.encode(config_base)) then
			push_Master()
		end
		config_base.autoSync.state = "Master"
		config_dict:replace("base",cjson_safe.encode(config_base))
	elseif config_base.autoSync.state == "Slave" then
		if pull_redisConfig() then
			save_configFile()
		end
		--推送count_dict到redis
		push_count_dict()
	else
		--推送count_dict到redis
		push_count_dict()
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