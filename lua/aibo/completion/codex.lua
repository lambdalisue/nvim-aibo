--- Completion module for Codex CLI in aibo prompt
--- Provides omnifunc-compatible completion for "/" skill/command shortcuts and
--- "@" file paths.
---
--- Live "/" completion is sourced by probing `codex` directly, not via the
--- Agent Client Protocol (ACP): Codex CLI does not speak ACP itself — that
--- needs a separate adapter (`codex-acp`, wrapping the Codex runtime). Since
--- aibo already hard-depends on the `codex` binary (it drives the
--- interactive session over a PTY), this module talks `codex`'s own
--- first-party `app-server` JSON-RPC protocol directly instead, so live
--- completion needs no adapter, no Node.js, and no npm. See
--- :help aibo-codex-probe for the design.
local M = {}

local probe = require("aibo.completion.probe")
local cache = require("aibo.completion.cwd_cache").new()

-- ============================================================================
-- Live probe: talk to `codex app-server` directly (initialize + skills/list)
-- ============================================================================
--
-- Protocol: `codex app-server` is a subcommand already built into the
-- `codex` binary itself (no separate package needed). Its JSON-RPC schema is
-- self-documenting -- running
-- `codex app-server generate-json-schema --out <dir> --experimental` dumps
-- the full JSON Schema, including the `skills/list` method used here.
--
--   spawn: codex app-server
--     -> write: {"id":1,"method":"initialize","params":{"clientInfo":{...}}}
--     -> read:  {"id":1,"result":{...}}
--     -> write: {"id":2,"method":"skills/list","params":{}}
--     -> read:  {"id":2,"result":{"data":[{"cwd":..,"skills":[...]}]}}
--     -> terminate
--
-- `thread/start` (Codex's prompt-execution method) is never called, so no
-- inference runs and no tokens are consumed.
--
-- Caveat: this is Codex's own internal control protocol, not a documented
-- public API in the "stable CLI flags" sense -- treat every failure mode
-- (timeout, parse error, exit, unrecognized response shape) as routine and
-- offer no commands.

-- Talk to the `codex` binary directly (already a hard dependency of aibo).
-- There is no separate adapter to resolve or install.
local DEFAULT_PROBE_CMD = { "codex" }
local PROBE_ARGS = { "app-server" }

---Convert `codex`'s `skills/list` response into aibo completion entries.
---Pure function -- the unit-testable core of the probe.
---@param data table[]|nil Array of { cwd, skills, errors } (SkillsListEntry)
---@return table[] entries List of { cmd = "/name", description = string }
function M._parse_skills_list(data)
  local entries = {}
  for _, entry in ipairs(data or {}) do
    if type(entry) == "table" then
      for _, skill in ipairs(entry.skills or {}) do
        if type(skill) == "table" and type(skill.name) == "string" and skill.name ~= "" then
          table.insert(entries, {
            cmd = "/" .. skill.name,
            description = type(skill.description) == "string" and skill.description or "",
          })
        end
      end
    end
  end
  return entries
end

---Get the cached probe entries for a directory, if any.
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

---Resolve the command to actually run: the configured `cmd` if it is
---executable, else the default `codex` binary.
---@param opts table|nil { cmd? }
---@return string[]|nil cmd Runnable command, or nil if not executable
function M.resolve_cmd(opts)
  opts = opts or {}
  local cmd = opts.cmd or DEFAULT_PROBE_CMD
  if vim.fn.executable(cmd[1]) == 1 then
    return cmd
  end
  return nil
end

---Check whether `codex` (or a configured override) is resolvable.
---@param opts table|nil { cmd? }
---@return boolean
function M.is_available(opts)
  return M.resolve_cmd(opts) ~= nil
end

---Asynchronously probe `codex app-server` for its live skill list and cache
---the result. Sends only `initialize` + `skills/list` -- never `thread/start`
----- so no tokens are consumed.
---@param opts table|nil { cwd?, cmd?, timeout? (ms) }
---@param callback fun(entries: table[]|nil, err: string|nil)|nil
local function refresh_probe(opts, callback)
  opts = opts or {}
  callback = callback or function() end
  local cwd = opts.cwd or vim.fn.getcwd()
  local cmd = M.resolve_cmd(opts)

  if not cmd then
    vim.schedule(function()
      callback(nil, "codex not found: " .. tostring((opts.cmd or DEFAULT_PROBE_CMD)[1]))
    end)
    return
  end

  local full_cmd = vim.deepcopy(cmd)
  for _, a in ipairs(PROBE_ARGS) do
    table.insert(full_cmd, a)
  end

  local next_id = 1
  local pending = {} -- id -> method name

  local function request(send, method, params)
    local id = next_id
    next_id = id + 1
    pending[id] = method
    send({ id = id, method = method, params = params or vim.empty_dict() })
  end

  probe.run(full_cmd, { cwd = cwd, timeout = opts.timeout, label = "codex app-server" }, {
    on_start = function(send)
      request(send, "initialize", { clientInfo = { name = "aibo", version = "1.0" } })
    end,
    on_message = function(msg, send, finish)
      if type(msg) ~= "table" or msg.id == nil or not pending[msg.id] then
        return
      end
      local method = pending[msg.id]
      pending[msg.id] = nil
      if msg.error then
        finish(nil, ("%s failed: %s"):format(method, vim.inspect(msg.error)))
        return
      end
      if method == "initialize" then
        request(send, "skills/list", {})
        return
      end
      if method == "skills/list" then
        finish(M._parse_skills_list((msg.result or {}).data))
      end
    end,
  }, function(entries, err)
    if entries then
      cache.set(cwd, entries)
    end
    callback(entries, err)
  end)
end

---Get all slash commands from the live probe cache. `codex`'s own
---`skills/list` response already includes the account's user/project/system
---skills, so there is no separate disk scan here. With the probe
---disabled/unavailable, no commands are offered (enable
---`tools.codex.completion.codex`; see :help aibo-codex-probe).
---@return table[] List of all command definitions
local function get_all_commands()
  return vim.deepcopy(M.get_cached() or {})
end

M.omnifunc = require("aibo.completion.omnifunc").make(get_all_commands)

---Get raw list of slash commands (for external use)
---@return table[] List of slash command definitions
function M.get_commands()
  return get_all_commands()
end

---Warm the live-probed command cache for the current directory (async).
---Fire-and-forget: completion offers nothing until the cache is populated.
---No prompt is ever sent, so this consumes no tokens. No-op-ish when `codex`
---is unavailable (the callback receives an error).
---@param opts table|nil { cwd?, cmd?, timeout? }
---@param callback fun(entries: table[]|nil, err: string|nil)|nil
function M.refresh_acp(opts, callback)
  opts = opts or {}
  callback = callback or function() end
  if not M.is_available(opts) then
    callback(nil, "codex not found: " .. tostring((opts.cmd or DEFAULT_PROBE_CMD)[1]))
    return
  end
  refresh_probe(opts, callback)
end

return M
