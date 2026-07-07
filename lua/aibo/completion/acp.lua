--- Generic Agent Client Protocol (ACP) completion source.
---
--- Talks the real, documented Agent Client Protocol
--- (https://agentclientprotocol.com) to any agent that speaks it *natively*
--- over stdio (e.g. `gemini --acp`, `copilot --acp`, `cursor-agent acp`,
--- `cline --acp`) purely to fetch the live list of available slash commands /
--- skills. It NEVER sends `session/prompt`, so it performs no model
--- inference and consumes no tokens — the command list is delivered as a
--- `session/update` notification (`available_commands_update`) that the agent
--- pushes right after `session/new`.
---
--- Unlike `completion/claude.lua` and `completion/codex.lua` — which talk
--- each agent's own internal, undocumented control protocol directly because
--- neither Claude nor Codex speaks ACP natively — this module is
--- agent-agnostic: callers must supply `cmd` for the ACP-native agent to
--- probe. See :help aibo-acp for which agents qualify.
---
--- The interactive session itself keeps running over a PTY elsewhere; this is
--- a read-only side-channel that only populates completion candidates.
---
--- Flow (no prompt turn):
---   spawn agent (stdio), e.g. { "gemini", "--acp" }
---     -> initialize                         # read agentCapabilities
---     -> session/new { cwd, mcpServers }    # cwd MUST match the live session
---     -> await available_commands_update    # session/update notification
---     -> cache availableCommands
---     -> terminate
local M = {}

local probe = require("aibo.completion.probe")
local cache = require("aibo.completion.cwd_cache").new()

---Convert an ACP `availableCommands` array into aibo completion entries.
---Pure function — the unit-testable core of this module.
---@param available table[]|nil ACP AvailableCommand objects ({ name, description, input? })
---@return table[] entries List of { cmd = "/name", description = string }
function M._parse_available_commands(available)
  local entries = {}
  for _, c in ipairs(available or {}) do
    -- Defensive: the agent may include malformed items; skip anything that
    -- is not a table with a non-empty string `name`.
    if type(c) == "table" and type(c.name) == "string" and c.name ~= "" then
      table.insert(entries, {
        cmd = "/" .. c.name,
        description = type(c.description) == "string" and c.description or "",
      })
    end
  end
  return entries
end

---Get the cached command entries for a directory, if any.
---@param cwd string|nil Defaults to the current working directory
---@return table[]|nil entries Cached entries, or nil on cache miss
function M.get_cached(cwd)
  return cache.get(cwd)
end

---Clear the probe cache.
---@param cwd string|nil If given, clear only that directory; otherwise clear all
function M.clear_cache(cwd)
  cache.clear(cwd)
end

---Resolve the agent command to actually run.
---@param opts table|nil { cmd? }
---@return string[]|nil cmd Runnable command, or nil if `cmd` is missing or not executable
function M.resolve_cmd(opts)
  opts = opts or {}
  local cmd = opts.cmd
  if type(cmd) == "table" and cmd[1] and vim.fn.executable(cmd[1]) == 1 then
    return cmd
  end
  return nil
end

---Check whether the configured agent command is available.
---@param opts table|nil { cmd? }
---@return boolean
function M.is_available(opts)
  return M.resolve_cmd(opts) ~= nil
end

---High-level entry point used by completion wiring: refresh the cache when
---the configured agent is resolvable, otherwise report why not.
---@param opts table|nil { cwd?, cmd?, timeout?, mcp_servers? }
---@param callback fun(entries: table[]|nil, err: string|nil)|nil
function M.ensure_and_refresh(opts, callback)
  opts = opts or {}
  callback = callback or function() end
  if not M.is_available(opts) then
    callback(nil, "ACP agent not found: " .. tostring(opts.cmd and opts.cmd[1]))
    return
  end
  M.refresh(opts, callback)
end

---Asynchronously probe the agent for available commands and cache the result.
---Never sends a prompt; no tokens are consumed.
---@param opts table|nil { cwd?, cmd?, timeout? (ms), mcp_servers? }
---@param callback fun(entries: table[]|nil, err: string|nil)|nil
function M.refresh(opts, callback)
  opts = opts or {}
  callback = callback or function() end
  local cwd = opts.cwd or vim.fn.getcwd()
  local cmd = M.resolve_cmd(opts)

  if not cmd then
    vim.schedule(function()
      callback(nil, "ACP agent not found: " .. tostring(opts.cmd and opts.cmd[1]))
    end)
    return
  end

  local next_id = 1
  local pending = {} -- id -> method name

  local function request(send, method, params)
    local id = next_id
    next_id = id + 1
    pending[id] = method
    send({ jsonrpc = "2.0", id = id, method = method, params = params or vim.empty_dict() })
  end

  probe.run(cmd, { cwd = cwd, timeout = opts.timeout, label = "ACP agent" }, {
    on_start = function(send)
      request(send, "initialize", {
        protocolVersion = 1,
        clientCapabilities = { fs = { readTextFile = true, writeTextFile = false } },
      })
    end,
    on_message = function(msg, send, finish)
      if type(msg) ~= "table" then
        return
      end

      -- Agent -> client request: answer minimally so the probe never stalls.
      if msg.method and msg.id ~= nil then
        if msg.method == "session/request_permission" then
          send({ jsonrpc = "2.0", id = msg.id, result = { outcome = { outcome = "cancelled" } } })
        else
          send({ jsonrpc = "2.0", id = msg.id, result = vim.empty_dict() })
        end
        return
      end

      -- Notification carrying the command list.
      if msg.method == "session/update" and type(msg.params) == "table" then
        local update = msg.params.update
        if type(update) == "table" and update.sessionUpdate == "available_commands_update" then
          finish(M._parse_available_commands(update.availableCommands))
        end
        return
      end

      -- Response to one of our requests.
      if msg.id ~= nil and pending[msg.id] then
        local method = pending[msg.id]
        pending[msg.id] = nil
        if msg.error then
          finish(nil, ("%s failed: %s"):format(method, vim.inspect(msg.error)))
          return
        end
        if method == "initialize" then
          request(send, "session/new", { cwd = cwd, mcpServers = opts.mcp_servers or {} })
        end
        -- After session/new the agent pushes available_commands_update as a
        -- notification; we simply wait for it (guarded by the timeout).
      end
    end,
  }, function(entries, err)
    if entries then
      cache.set(cwd, entries)
    end
    callback(entries, err)
  end)
end

return M
