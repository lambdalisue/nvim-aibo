--- Tiny per-cwd result cache shared by completion/{acp,claude,codex}.lua.
--- Each probe module keeps its own cache instance (they are not meant to be
--- shared across modules), keyed by working directory, with no TTL -- a
--- stale entry is still strictly more accurate than a static table, and
--- each ftplugin only warms the cache once per cwd per session.
local M = {}

---Create a new, independent cache instance.
---@return table { get: fun(cwd?: string): any, set: fun(cwd: string, value: any), clear: fun(cwd?: string) }
function M.new()
  local entries = {}
  local instance = {}

  ---@param cwd string|nil Defaults to the current working directory
  function instance.get(cwd)
    return entries[cwd or vim.fn.getcwd()]
  end

  ---@param cwd string
  ---@param value any
  function instance.set(cwd, value)
    entries[cwd] = value
  end

  ---@param cwd string|nil If given, clear only that directory; otherwise clear all
  function instance.clear(cwd)
    if cwd then
      entries[cwd] = nil
    else
      entries = {}
    end
  end

  return instance
end

return M
