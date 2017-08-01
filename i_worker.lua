local _worker_count = ngx.worker.count()
local _worker_id = ngx.worker.id()

local config_dict = ngx.shared.config_dict
local cjson_safe = require "cjson.safe"
local http = require "resty.http"

local handler
local handler_all
local handler_zero

local config_base


-- dict 清空过期内存
local function flush_expired_dict()
	local dict_list = {"token_dict","count_dict","config_dict","host_dict","ip_dict","limit_ip_dict"}
	for _,v in ipairs(dict_list) do
		ngx.shared[v]:flush_expired()
	end
end

-- 拉取config_dict配置数据
local function pull_redisConfig()

	-- local httpc = http.new()
	-- local _pull_url = "http://127.0.0.1:5460/api/dict_redis?action=pull&key=all_dict"
	-- local res, err = httpc:request_uri(_push_url,{
	--        method = "GET",
	--        headers = {
	--          ["Host"] = "127.0.0.1:5460",
	--        }
	--      })

	local httpc = http.new()
	-- The generic form gives us more control. We must connect manually.
	httpc:set_timeout(500)
	httpc:connect("127.0.0.1", 5460)

	-- And request using a path, rather than a full URI.
	local res, err = httpc:request{
	  path = "/api/dict_redis?action=pull&key=all_dict",
	  headers = {
	      ["Host"] = "127.0.0.1:5460",
	  },
	}

	if not res then
		ngx.log(ngx.ERR, "failed to pull_redisConfig request: ", err)
		return
	else
		return true
	end
end

-- 推送config_dict、host_dict、count_dict到redis
local function push_Master()

	local httpc = http.new()
	-- The generic form gives us more control. We must connect manually.
	httpc:set_timeout(500)
	httpc:connect("127.0.0.1", 5460)

	local res, err = httpc:request{
	  path = "/api/dict_redis?action=push&key=all_dict&slave=yes",
	  headers = {
	      ["Host"] = "127.0.0.1:5460",
	  },
	}

	if not res then
		ngx.log(ngx.ERR, "failed to push_Master request: ", err)
		return
	else
		return true
	end
end

-- 推送count_dict统计、计数等
local function push_count_dict()

	local httpc = http.new()
	-- The generic form gives us more control. We must connect manually.
	httpc:set_timeout(500)
	httpc:connect("127.0.0.1", 5460)

	-- And request using a path, rather than a full URI.
	-- 目前是调试阶段 denug=yes ,否则就是 no
	local res, err = httpc:request{
	  path = "/api/dict_redis?action=push&key=count_dict",
	  headers = {
	      ["Host"] = "127.0.0.1:5460",
	  },
	}

	if not res then
		ngx.log(ngx.ERR, "failed to push_count_dict request: ", err)
		return
	else
		return true
	end
end

-- 保存config_dict、host_dict到本机文件
local function save_configFile(_debug)

	local httpc = http.new()

	-- The generic form gives us more control. We must connect manually.
	httpc:set_timeout(500)
	httpc:connect("127.0.0.1", 5460)

	-- And request using a path, rather than a full URI.
	-- 调试阶段debug=yes 否则应该是 no
	local res, err = httpc:request{
	  path = "/api/config?action=save&mod=all_mod&debug=".._debug,
	  headers = {
	      ["Host"] = "127.0.0.1:5460",
	  },
	}

	if not res then
		ngx.log(ngx.ERR, "failed to save_configFile request: ", err)
		return
	else
		return true
	end
end

handler_zero = function ()
	-- do something	
	
	local config = cjson_safe.decode(config_dict:get("config")) or {}
	config_base = config.base or {}
	local timeAt = config_base.autoSync.timeAt or 5
	-- 如果 auto Sync 开启 就定时从redis 拉取配置并推送一些计数
	if config_base.autoSync.state == "Master" then
			push_Master()
	elseif config_base.autoSync.state == "Slave" then
		if pull_redisConfig() then
			local _debug = "no"
			if config_base.debug_Mod then
				_debug = "yes"
			end
			save_configFile(_debug)
		end
		--推送count_dict到redis
		push_count_dict()
	else
		-- nothing todo
	end

	--清空过期内存
	ngx.thread.spawn(flush_expired_dict)

	--
	local ok, err = ngx.timer.at(timeAt, handler_zero)
	if not ok then
		ngx.log(ngx.ERR, "failed to startup handler_zero worker...", err)
	end
end

handler_all = function ()
	local optl = require("optl")
	local dict_config_version = config_dict:get("config_version")
	local optl_config_version = optl.config_version
	if dict_config_version ~= optl_config_version then
		local config = cjson_safe.decode(config_dict:get("config"))
		-- 简单判断config,最好是内容规则的判断
		if config ~= nil then
			optl.config = config
			optl.config_version = dict_config_version
		end
	end
	local ok, err = ngx.timer.at(1, handler_all)
	if not ok then
		ngx.log(ngx.ERR, "failed to startup handler_all worker...", err)
	end
end

handler = function()
	handler_all()
	if _worker_id == 0 then
		handler_zero()
	end
end

local ok, err = ngx.timer.at(0, handler)
if not ok then
	ngx.log(ngx.ERR, "failed to startup handler worker...", err)
end