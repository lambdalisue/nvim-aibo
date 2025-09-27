local M = {}

---@class AiboBufferConfig
---@field on_attach? fun(bufnr: integer, info: table) Callback for buffer attachment
---@field no_default_mappings? boolean Disable default key mappings

---@class AiboConfig
---@field prompt? AiboBufferConfig Configuration for prompt buffers
---@field console? AiboBufferConfig Configuration for console buffers
---@field agents? table<string, AiboBufferConfig> Agent-specific configurations
---@field submit_delay? integer Delay before submit in ms (default: 100)
---@field prompt_height? integer Height of prompt window (default: 10)

---@type AiboConfig
local DEFAULTS = {
  prompt = {
    on_attach = nil,
    no_default_mappings = false,
  },
  console = {
    on_attach = nil,
    no_default_mappings = false,
  },
  -- Agent-specific configurations can be added here
  agents = {},
  submit_key = "<CR>",
  submit_delay = 100,
  prompt_height = 10,
}

---@type AiboConfig
local config = vim.deepcopy(DEFAULTS)

---@param bufnr integer Buffer number
---@return nil or { bufnr: integer, bufname: string, winid: integer, console_info?: table }
local function find_console_info(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname:match("^aiboconsole://") then
    local console = require("aibo.internal.console_window")
    return console.get_info_by_bufnr(bufnr)
  elseif bufname:match("^aiboprompt://") then
    local prompt = require("aibo.internal.prompt_window")
    local info = prompt.get_info_by_bufnr(bufnr)
    if not info or not info.console_info then
      return nil
    end
    return info.console_info
  end
  return nil
end

---Setup function to configure aibo
---@param opts? AiboConfig Configuration options
function M.setup(opts)
  -- Check Neovim version (silently skip if not satisfied)
  if vim.fn.has("nvim-0.10.0") ~= 1 then
    return
  end
  config = vim.tbl_deep_extend("force", config, opts or {})
end

---Get the configuration
---@return AiboConfig Current configuration (cloned)
function M.get_config()
  -- Return a deep copy to prevent accidental modification
  return vim.deepcopy(config)
end

---Get configuration for a specific buffer type
---@param buftype "prompt"|"console" Buffer type
---@return AiboBufferConfig Buffer type configuration
function M.get_buffer_config(buftype)
  return vim.deepcopy(config[buftype] or {})
end

---Get configuration for a specific agent
---@param agent string Agent name (e.g., "claude", "codex")
---@return AiboBufferConfig Configuration for the agent (cloned)
function M.get_agent_config(agent)
  -- Start with base configuration for buffer type
  if agent and config.agents and config.agents[agent] then
    return vim.deepcopy(config.agents[agent])
  end
  return {}
end

---Send data to the terminal
---@param data string Data to send
---@param bufnr? integer Buffer number
---@return nil
function M.send(data, bufnr)
  local console = require("aibo.internal.console_window")
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local console_info = find_console_info(bufnr)
  if console_info then
    console.send(console_info.bufnr, data)
  end
end

---Submit data to the terminal with automatic return key
---@param data string Data to submit
---@param bufnr? integer Buffer number
---@return nil
function M.submit(data, bufnr)
  local console = require("aibo.internal.console_window")
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local console_info = find_console_info(bufnr)
  if console_info then
    console.submit(console_info.bufnr, data)
  end
end

-- Expose termcode as part of the public API
M.termcode = require("aibo.termcode")

return M
