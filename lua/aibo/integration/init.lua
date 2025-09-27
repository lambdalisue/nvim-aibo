local M = {}

local INTEGRATIONS = {
  claude = "aibo.integration.claude",
  codex = "aibo.integration.codex",
  ollama = "aibo.integration.ollama",
}

-- Load integration module
---@param name string The integration name
function M.get_module(name)
  local module_path = INTEGRATIONS[name]
  if not module_path then
    return nil
  end
  local ok, module = pcall(require, module_path)
  if not ok then
    vim.notify(
      string.format("Failed to load module for integration: %s", name),
      vim.log.levels.ERROR,
      { title = "Aibo integration error" }
    )
    return nil
  end
  return module
end

-- List available tool integrations
---@return string[] List of integration names
function M.available_integrations()
  return vim.tbl_keys(INTEGRATIONS)
end

---Check if claude command is available
---@return boolean
function M.is_available(name)
  local module = M.get_module(name)
  if module and module.check_health then
    return module.is_available()
  end
  return false
end

-- Run health check for tool integration
---@param name string The integration name
---@param report table Health check reporter functions
function M.check_health(name, report)
  local module = M.get_module(name)
  if module and module.check_health then
    return module.check_health(report)
  end
  return true
end

-- Get tool specific command completion candidates
---@param name string The integration name
---@param arglead string Current argument being typed
---@param cmdline string Full command line
---@param cursorpos integer Cursor position
---@return string[] Completion candidates
function M.get_command_completions(name, arglead, cmdline, cursorpos)
  local module = M.get_module(name)
  if module and module.get_command_completions then
    local ok, result = pcall(module.get_command_completions, arglead, cmdline, cursorpos)
    if ok then
      return result
    end
  end
  return {}
end

-- Setup tool specific mappings
---@param name string The integration name
---@param bufnr number Buffer number to set mappings for
function M.setup_mappings(name, bufnr)
  local module = M.get_module(name)
  if module and module.setup_mappings then
    module.setup_mappings(bufnr)
  end
end

return M
