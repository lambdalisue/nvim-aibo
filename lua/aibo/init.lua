local M = {}

---@class AiboBufferConfig
---@field on_attach? fun(bufnr: integer, info: table) Callback for buffer attachment
---@field no_default_mappings? boolean Disable default key mappings

---@class AiboConfig
---@field prompt? AiboBufferConfig Configuration for prompt buffers
---@field console? AiboBufferConfig Configuration for console buffers
---@field tools? table<string, AiboBufferConfig> Tool-specific configurations
---@field submit_key? string Key to submit input (default: "<CR>")
---@field submit_delay? integer Delay before submit in ms (default: 100)
---@field prompt_height? integer Height of prompt window (default: 10)
---@field termcode_mode? string Terminal escape sequence mode: "hybrid", "xterm", or "csi-n" (default: "hybrid")
---@field disable_startinsert_on_startup? boolean Disable auto insert mode in prompt window when first opened (default: false)
---@field disable_startinsert_on_insert? boolean Disable auto insert mode in prompt window when entering insert mode from console (default: false)

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
  -- Tool-specific configurations can be added here
  tools = {},
  submit_key = "<CR>",
  submit_delay = 100,
  prompt_height = 10,
  termcode_mode = "hybrid",
  disable_startinsert_on_startup = false,
  disable_startinsert_on_insert = false,
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

---Get configuration for a specific tool
---@param tool string Tool name (e.g., "claude", "codex")
---@return AiboBufferConfig Configuration for the tool (cloned)
function M.get_tool_config(tool)
  -- Start with base configuration for buffer type
  if tool and config.tools and config.tools[tool] then
    return vim.deepcopy(config.tools[tool])
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

---Resolve Vim-style key notation to terminal escape sequences using configured termcode_mode
---@param input string Key notation like "<Up>", "<C-A>", "<S-F5>", "<Up><Down>"
---@return string|nil Terminal escape sequence, or nil if unable to resolve
function M.resolve(input)
  local termcode = require("aibo.internal.termcode")
  return termcode.resolve(input, { mode = config.termcode_mode })
end

return M
