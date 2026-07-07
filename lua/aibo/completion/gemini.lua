--- Completion module for Gemini CLI in aibo prompt
--- Provides omnifunc-compatible completion for "/" slash commands and "@" file paths.
---
--- Gemini CLI speaks the Agent Client Protocol (ACP) natively (`gemini --acp`),
--- so live "/" completion is sourced via the generic ACP client
--- (`completion/acp.lua`) -- no adapter, no extra dependency beyond `gemini`
--- itself, which aibo's Gemini integration already requires.
---
--- Caveat: `completion/acp.lua`'s cache is keyed only by cwd, not by agent.
--- This is fine while Gemini is the only agent routed through it; if another
--- ACP-native agent (Copilot, Cursor, Cline, ...) is wired up for the same
--- cwd at the same time, they would currently share -- and clobber -- each
--- other's cached entries. Revisit if/when that happens.
local M = {}

local acp = require("aibo.completion.acp")

local DEFAULT_PROBE_CMD = { "gemini", "--acp" }

---Get all completion entries from the live ACP-probed list. There is no
---static builtin table for Gemini; with the probe disabled/unavailable, no
---slash commands are offered.
---@return table[] List of all command definitions
local function get_all_commands()
  return vim.deepcopy(acp.get_cached() or {})
end

M.omnifunc = require("aibo.completion.omnifunc").make(get_all_commands)

---Get raw list of slash commands (for external use)
---@return table[] List of slash command definitions
function M.get_commands()
  return get_all_commands()
end

---Resolve the command to actually probe: the configured `cmd` if it is
---executable, else the default `gemini --acp`.
---@param opts table|nil { cmd? }
---@return string[]|nil cmd Runnable command, or nil if not executable
function M.resolve_cmd(opts)
  opts = opts or {}
  return acp.resolve_cmd({ cmd = opts.cmd or DEFAULT_PROBE_CMD })
end

---Get the cached ACP-probed entries for a directory, if any.
---@param cwd string|nil Defaults to the current working directory
---@return table[]|nil entries
function M.get_cached(cwd)
  return acp.get_cached(cwd)
end

---Warm the ACP-probed command cache for the current directory (async).
---Fire-and-forget: completion offers nothing until the cache is populated.
---No prompt is ever sent, so this consumes no tokens. No-op-ish when
---`gemini` is unavailable (the callback receives an error).
---@param opts table|nil { cwd?, cmd?, timeout?, mcp_servers? }
---@param callback fun(entries: table[]|nil, err: string|nil)|nil
function M.refresh_acp(opts, callback)
  opts = opts or {}
  opts.cmd = opts.cmd or DEFAULT_PROBE_CMD
  acp.ensure_and_refresh(opts, callback)
end

return M
