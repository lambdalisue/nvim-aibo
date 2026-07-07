--- Shared async subprocess-probe scaffolding for completion/{acp,claude,codex}.lua.
---
--- Each of those modules speaks a different wire protocol to a different
--- agent binary, but the plumbing around it is identical: spawn a
--- short-lived child process, buffer stdout and split it into
--- newline-delimited JSON messages, dispatch each decoded message to the
--- caller, and resolve to a result or error -- guarded by a timeout and
--- "exited before responding" handling. This module is that plumbing;
--- protocol-specific request/response handling stays in each caller.
local M = {}

local uv = vim.uv or vim.loop

---Spawn `cmd` and exchange newline-delimited JSON messages with it.
---@param cmd string[] Full argv to spawn
---@param opts table|nil { cwd?: string, timeout?: integer (ms), label?: string }
---@param handlers table { on_start: fun(send: fun(obj: table)), on_message: fun(msg: table, send: fun(obj: table), finish: fun(result: any, err: string|nil)) }
---@param callback fun(result: any, err: string|nil)
function M.run(cmd, opts, handlers, callback)
  opts = opts or {}
  local cwd = opts.cwd or vim.fn.getcwd()
  local timeout = opts.timeout or 10000
  local label = opts.label or cmd[1]

  local state = { buf = "", stderr = "", done = false, proc = nil, timer = nil }

  local function finish(result, err)
    if state.done then
      return
    end
    state.done = true
    if state.timer then
      state.timer:stop()
      state.timer:close()
      state.timer = nil
    end
    if state.proc then
      pcall(function()
        state.proc:kill("sigterm")
      end)
    end
    vim.schedule(function()
      callback(result, err)
    end)
  end

  local function send(obj)
    pcall(function()
      state.proc:write(vim.json.encode(obj) .. "\n")
    end)
  end

  local function on_stdout(err, data)
    if err or not data or state.done then
      return
    end
    state.buf = state.buf .. data
    while true do
      local nl = state.buf:find("\n", 1, true)
      if not nl then
        break
      end
      local line = vim.trim(state.buf:sub(1, nl - 1))
      state.buf = state.buf:sub(nl + 1)
      if line ~= "" then
        local ok, decoded = pcall(vim.json.decode, line)
        if ok then
          vim.schedule(function()
            if not state.done then
              handlers.on_message(decoded, send, finish)
            end
          end)
        end
      end
    end
  end

  local function on_stderr(err, data)
    if err or not data then
      return
    end
    state.stderr = state.stderr .. data
  end

  state.proc = vim.system(cmd, {
    cwd = cwd,
    stdin = true,
    stdout = on_stdout,
    stderr = on_stderr,
    text = true,
  }, function(obj)
    -- The process exited. If it died before responding, surface an
    -- early-exit error (with stderr) instead of waiting the full timeout --
    -- much faster and easier to debug than a generic timeout.
    vim.schedule(function()
      if not state.done then
        local detail = vim.trim(state.stderr)
        local msg = ("%s exited early (code %s)"):format(label, tostring(obj.code))
        if detail ~= "" then
          msg = msg .. ": " .. detail
        end
        finish(nil, msg)
      end
    end)
  end)

  state.timer = uv.new_timer()
  state.timer:start(timeout, 0, function()
    finish(nil, ("%s probe timed out"):format(label))
  end)

  handlers.on_start(send)
end

return M
