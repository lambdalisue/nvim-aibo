--- Completion module for Claude Code in aibo prompt
--- Provides omnifunc-compatible completion for "/" slash commands and "@" file paths
---
--- Live "/" completion is sourced by probing `claude` directly (see the
--- "Live probe" section below), not via the Agent Client Protocol (ACP):
--- Claude Code does not speak ACP itself — that needs a separate adapter
--- (`claude-agent-acp`, wrapping the Claude Agent SDK). Since aibo already
--- hard-depends on the `claude` binary (it drives the interactive session
--- over a PTY), this module talks `claude`'s own internal stream-json
--- control protocol directly instead, so live completion needs no adapter,
--- no Node.js, and no npm. See :help aibo-claude-probe for the design.
local M = {}

local probe = require("aibo.completion.probe")
local cache = require("aibo.completion.cwd_cache").new()

-- ============================================================================
-- Live probe: talk to `claude` directly (control_request/control_response)
-- ============================================================================
--
-- Protocol (reverse-engineered from `@anthropic-ai/claude-agent-sdk`'s
-- `sdk.mjs`, which `claude-agent-acp` itself uses to drive `claude`):
--   spawn: claude --output-format stream-json --verbose \
--                 --input-format stream-json --no-session-persistence
--     -> write one line: {"request_id":.., "type":"control_request",
--                          "request":{"subtype":"initialize"}}
--     -> read one line back: {"type":"control_response",
--          "response":{"subtype":"success","request_id":..,
--                       "response":{"commands":[...]}}}
--     -> terminate
--
-- This is a control-plane request/response, not a prompt turn — no `user`
-- message is ever sent, so no inference runs and no tokens are consumed.
-- `--no-session-persistence` additionally leaves no session-history file
-- under `~/.claude/projects`.
--
-- Caveat: unlike ACP, this wire format is undocumented and internal to the
-- Claude Agent SDK — it has no version guarantee and can change on any
-- `claude` release without notice. Failures are treated as routine (timeout,
-- parse error, exit) and no commands are offered.

-- Talk to the `claude` binary directly (already a hard dependency of aibo).
-- There is no separate adapter to resolve or install.
local DEFAULT_PROBE_CMD = { "claude" }

-- Extra CLI flags that put `claude` into the stream-json control-protocol
-- mode this module speaks, without persisting a session-history entry.
local PROBE_ARGS = {
  "--output-format",
  "stream-json",
  "--verbose",
  "--input-format",
  "stream-json",
  "--no-session-persistence",
}

local PROBE_REQUEST_ID = "aibo-probe"

---Convert `claude`'s control_response `commands` array into aibo completion
---entries. Pure function — the unit-testable core of the probe.
---@param available table[]|nil Command objects ({ name, description, argumentHint?, aliases? })
---@return table[] entries List of { cmd = "/name", description = string }
function M._parse_available_commands(available)
  local entries = {}
  for _, c in ipairs(available or {}) do
    -- Defensive: `claude` may include malformed items; skip anything that is
    -- not a table with a non-empty string `name`.
    if type(c) == "table" and type(c.name) == "string" and c.name ~= "" then
      table.insert(entries, {
        cmd = "/" .. c.name,
        description = type(c.description) == "string" and c.description or "",
      })
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
---executable, else the default `claude` binary.
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

---Check whether `claude` (or a configured override) is resolvable.
---@param opts table|nil { cmd? }
---@return boolean
function M.is_available(opts)
  return M.resolve_cmd(opts) ~= nil
end

---Asynchronously probe `claude` for its live command list and cache the
---result. Sends only a control-plane `initialize` request — never a prompt —
---so no tokens are consumed.
---@param opts table|nil { cwd?, cmd?, timeout? (ms) }
---@param callback fun(entries: table[]|nil, err: string|nil)|nil
local function refresh_probe(opts, callback)
  opts = opts or {}
  callback = callback or function() end
  local cwd = opts.cwd or vim.fn.getcwd()
  local cmd = M.resolve_cmd(opts)

  if not cmd then
    vim.schedule(function()
      callback(nil, "claude not found: " .. tostring((opts.cmd or DEFAULT_PROBE_CMD)[1]))
    end)
    return
  end

  local full_cmd = vim.deepcopy(cmd)
  for _, a in ipairs(PROBE_ARGS) do
    table.insert(full_cmd, a)
  end

  probe.run(full_cmd, { cwd = cwd, timeout = opts.timeout, label = "claude" }, {
    on_start = function(send)
      send({
        request_id = PROBE_REQUEST_ID,
        type = "control_request",
        request = { subtype = "initialize" },
      })
    end,
    on_message = function(msg, _send, finish)
      if type(msg) ~= "table" or msg.type ~= "control_response" then
        return
      end
      local response = msg.response
      if type(response) ~= "table" or response.request_id ~= PROBE_REQUEST_ID then
        return
      end
      if response.subtype == "error" then
        finish(nil, ("initialize failed: %s"):format(vim.inspect(response.error)))
        return
      end
      if response.subtype == "success" then
        finish(M._parse_available_commands((response.response or {}).commands))
      end
    end,
  }, function(entries, err)
    if entries then
      cache.set(cwd, entries)
    end
    callback(entries, err)
  end)
end

---Get all slash commands from the live probe cache. `claude`'s own command
---list already includes the account's custom commands/skills (tagged e.g.
---"(user)" by `claude` itself), so there is no separate disk scan here --
---unlike a static table, the live probe can't drift out of sync with what's
---actually on disk. With the probe disabled/unavailable, no commands are
---offered (enable `tools.claude.completion.claude`; see :help aibo-claude-probe).
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
---No prompt is ever sent, so this consumes no tokens. No-op-ish when
---`claude` is unavailable (the callback receives an error).
---@param opts table|nil { cwd?, cmd?, timeout? }
---@param callback fun(entries: table[]|nil, err: string|nil)|nil
function M.refresh_acp(opts, callback)
  opts = opts or {}
  callback = callback or function() end
  if not M.is_available(opts) then
    callback(nil, "claude not found: " .. tostring((opts.cmd or DEFAULT_PROBE_CMD)[1]))
    return
  end
  refresh_probe(opts, callback)
end

return M
