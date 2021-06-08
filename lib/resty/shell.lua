local _M = {
    version = 0.03
}


local resty_sig = require "resty.signal"
local ngx_pipe = require "ngx.pipe"
local new_tab = require "table.new"
local tablepool = require "tablepool"


local kill = resty_sig.kill
local pipe_spawn = ngx_pipe.spawn
local tostring = tostring
local spawn_thread = ngx.thread.spawn
local wait_thread = ngx.thread.wait
local concat = table.concat
local fetch_tab = tablepool.fetch
local release_tab = tablepool.release
local sleep = ngx.sleep


local spawn_opts = {
    buffer_size = 1024 * 32  -- 32K
}


local tab_pool_tag = "resty.shell"


local function cleanup_proc(proc)
    local pid = proc:pid()
    if pid then
        local ok, err = kill(pid, "TERM")
        if not ok then
            return nil, "failed to kill process " .. pid
                .. ": " .. tostring(err)
        end
        sleep(0.001)  -- only wait for 1 msec
        kill(pid, "KILL")
    end

    return true
end


local function concat_err(err1, err2)
    return tostring(err1) .. "; " .. tostring(err2)
end


local function read_stream(proc, buf, max_size, meth_name)
    local pos = 1
    local len = 0

    while len <= max_size do
        local data, err, partial = proc[meth_name](proc, max_size - len + 1)
        if not data then
            if partial then
                buf[pos] = partial
                pos = pos + 1
                len = len + #partial
            end

            if err == "closed" then
                return pos - 1
            end

            return pos - 1, err
        end

        buf[pos] = data
        pos = pos + 1
        len = len + #data
    end

    if len > max_size then
        return pos - 1, "too much data"
    end

    return pos - 1
end


function _M.run(cmd, stdin, timeout, max_size)
    if not max_size then
        max_size = 128 * 1024  -- 128KB
    end

    local proc, err = pipe_spawn(cmd, spawn_opts)
    if not proc then
        return nil, nil, nil, "failed to spawn: " .. tostring(err)
    end

    proc:set_timeouts(timeout, timeout, timeout, timeout)

    if stdin and stdin ~= "" then
        local bytes, err = proc:write(stdin)
        if not bytes then
            local ok2, err2 = cleanup_proc(proc)
            if not ok2 then
                err = concat_err(err, err2)
            end
            return nil, nil, nil, "failed to write to stdin: " .. tostring(err)
        end
    end

    local ok
    ok, err = proc:shutdown("stdin")
    if not ok then
        local ok2, err2 = cleanup_proc(proc)
        if not ok2 then
            err = concat_err(err, err2)
        end
        return nil, nil, nil, "failed to shutdown stdin: " .. tostring(err)
    end

    local stdout_tab = fetch_tab(tab_pool_tag, 4, 0)
    local stderr_tab = fetch_tab(tab_pool_tag, 4, 0)

    local thr_out = spawn_thread(read_stream, proc, stdout_tab, max_size,
                                 "stdout_read_any")
    local thr_err = spawn_thread(read_stream, proc, stderr_tab, max_size,
                                 "stderr_read_any")

    local reason, status
    ok, reason, status = proc:wait()

    if ok == nil and reason ~= "exited" then
        err = reason
        local ok2, err2 = cleanup_proc(proc)
        if not ok2 then
            err = concat_err(err, err2)
        end

        local stdout = concat(stdout_tab)
        release_tab(tab_pool_tag, stdout_tab)

        local stderr = concat(stderr_tab)
        release_tab(tab_pool_tag, stderr_tab)

        return nil, stdout, stderr,
               "failed to wait for process: " .. tostring(err)
    end

    local ok2, stdout_pos, err2 = wait_thread(thr_out)
    if not ok2 then
        local stdout = concat(stdout_tab)
        release_tab(tab_pool_tag, stdout_tab)

        local stderr = concat(stderr_tab)
        release_tab(tab_pool_tag, stderr_tab)

        return nil, stdout, stderr, "failed to wait stdout thread: "
            .. tostring(stdout_pos)
    end

    if err2 then
        local stdout = concat(stdout_tab, "", 1, stdout_pos)
        release_tab(tab_pool_tag, stdout_tab)

        local stderr = concat(stderr_tab)
        release_tab(tab_pool_tag, stderr_tab)

        return nil, stdout, stderr, "failed to read stdout: " .. tostring(err2)
    end

    local stderr_pos
    ok2, stderr_pos, err2 = wait_thread(thr_err)
    if not ok2 then
        local stdout = concat(stdout_tab, "", 1, stdout_pos)
        release_tab(tab_pool_tag, stdout_tab)

        local stderr = concat(stderr_tab)
        release_tab(tab_pool_tag, stderr_tab)

        return nil, stdout, stderr, "failed to wait stderr thread: "
            .. tostring(stderr_pos)
    end

    local stdout = concat(stdout_tab, "", 1, stdout_pos)
    release_tab(tab_pool_tag, stdout_tab)

    local stderr = concat(stderr_tab, "", 1, stderr_pos)
    release_tab(tab_pool_tag, stderr_tab)

    if err2 then
        return nil, stdout, stderr, "failed to read stderr: " .. tostring(err2)
    end

    return ok, stdout, stderr, reason, status
end


return _M
