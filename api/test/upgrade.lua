-- 自主updata接口
-- 调试使用，一些参数还没做安全检查，线上谨慎使用

local cjson_safe = require "cjson.safe"
local optl = require("optl")

local config_base = optl.config.base or {}

local get_argsByName = optl.get_argsByName
local ngx_path = ngx.config.prefix()

-- 接受相关参数
local _git_uri = "https://github.com/starjun/openstar.git"
local _install_path = get_argsByName("install_path")
if _install_path == "" then
    _install_path = "/opt/openresty"
end
local _openstar_path = _install_path.."/openstar"
local _openstar_bak_path = _install_path.."/openstar."..(os.date("%Y-%m-%d-%H-%M-%S", os.time()))..".bak"

local _update_config = get_argsByName("update_config")
local _git_branch = get_argsByName("git_branch")
if _git_branch == "" then
	_git_branch = "master"
end

-- alias 异常处理
os.execute("alias cp='cp'")
os.execute("alias rm='rm'")
os.execute("alias mv='mv'")

-- 备份旧版本openstar
local mv_res = os.execute(string.format("mv -f %s %s", _openstar_path, _openstar_bak_path))
if not mv_res then
    optl.sayHtml_ext({code='error', msg='failed to backup old version of openstar'})
end
-- 下载新版本openstar
local _res = os.execute(string.format("cd %s && git clone %s %s", _install_path, _git_uri, _openstar_path))
if not _res then
    os.execute(string.format("rm -rf %s", _openstar_path))
    os.execute(string.format("mv -f %s %s", _openstar_bak_path, _openstar_path))
    local _msg = string.format("failed to git clone[%s]: %s", tostring(_res), _git_uri)
    optl.sayHtml_ext({code='error', msg=_msg})
end
-- 其他操作
os.execute(string.format("cd %s && git checkout %s && mv -f .git .gitbak", _openstar_path, _git_branch))
os.execute(string.format("ln -sf %s/conf/nginx.conf %s/nginx/conf/nginx.conf", _openstar_path, _install_path))
os.execute(string.format("ln -sf %s/conf/waf.conf %s/nginx/conf/waf.conf", _openstar_path, _install_path))

if _update_config ~= "on" then
	-- 复制旧版的配置和规则	
	os.execute(string.format("cp -Rf %s/conf_json %s", _openstar_bak_path, _openstar_path))	
end
-- 删除旧版本
--os.execute(string.format("rm -rf %s", _openstar_bak_path))

-- alias 恢复处理
os.execute("alias cp='cp -i'")
os.execute("alias rm='rm -i'")
os.execute("alias mv='mv -i'")

local nginxtest = ngx_path.."sbin/nginx -t"
if os.execute(nginxtest) then
    local reload_comm = ngx_path.."sbin/nginx -s reload"
    local reload_re = os.execute(reload_comm)
    if not reload_re then
        optl.sayHtml_ext({code='error', msg='failed to reload nginx'})
    end

    optl.sayHtml_ext({code='ok', msg='successful upgrade openstar'})
else
    optl.sayHtml_ext({code='error', msg='nginx -t error'})
end