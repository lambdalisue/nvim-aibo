-- Mock utilities for aibo tests
-- These functions are primarily used by integration tests to simulate external commands
-- without actually executing them (e.g., mocking 'claude', 'codex', 'ollama' commands)

local M = {}

--- Mock vim.fn.executable to simulate command availability
--- Primarily used in integration tests to simulate external tool availability
--- @param commands table<string, boolean> Mapping of command names to their availability
--- @return function restore Function to restore original behavior
function M.mock_executable(commands)
  local original = vim.fn.executable
  vim.fn.executable = function(cmd)
    if commands[cmd] ~= nil then
      return commands[cmd] and 1 or 0
    end
    return original(cmd)
  end
  return function()
    vim.fn.executable = original
  end
end

--- Mock vim.fn.system to simulate command output
--- Primarily used in integration tests to simulate command execution results
--- (e.g., mocking 'ollama list' output without requiring ollama to be installed)
--- @param outputs table<string, {result: string, error?: number}> Mapping of command patterns to their outputs
--- @return function restore Function to restore original behavior
function M.mock_system(outputs)
  local original = vim.fn.system
  vim.fn.system = function(cmd)
    local cmd_str = type(cmd) == "table" and table.concat(cmd, " ") or cmd
    for pattern, output in pairs(outputs) do
      if cmd_str:match(pattern) then
        return output.result or ""
      end
    end
    return original(cmd)
  end
  return function()
    vim.fn.system = original
  end
end

return M
