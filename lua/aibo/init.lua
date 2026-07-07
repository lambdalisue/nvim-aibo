local M = {}

---@class AiboProbeConfig
---@field cmd? string[] Command to probe, looked up on PATH (default varies per source; see completion/*.lua)
---@field timeout? integer Probe timeout in ms (default: 10000)

---@class AiboCompletionConfig
---@field claude? AiboProbeConfig|boolean Source "/" completion from a live probe of `claude`'s own command list (Claude does not speak ACP itself). See completion/claude.lua. Enabled by default on the `claude` tool (there is no static fallback).
---@field codex? AiboProbeConfig|boolean Source "/" completion from a live probe of `codex`'s own skill list (Codex does not speak ACP itself). See completion/codex.lua. Enabled by default on the `codex` tool (there is no static fallback).
---@field acp? AiboProbeConfig|boolean Source "/" completion from a live probe over the real Agent Client Protocol (ACP), for agents that speak it natively. Currently wired up for Gemini CLI (`gemini --acp`). See completion/acp.lua and completion/gemini.lua. Enabled by default on the `gemini` tool (there is no static fallback).

---@class AiboBufferConfig
---@field on_attach? fun(bufnr: integer, info: table) Callback for buffer attachment
---@field no_default_mappings? boolean Disable default key mappings
---@field completion? AiboCompletionConfig Live "/" completion source(s) for this tool, keyed by completion module name (claude/codex/acp). Only meaningful under `tools.<name>` -- see completion/prompt_ftplugin.lua for which module each built-in tool ftplugin wires up.

---@class AiboConfig
---@field prompt? AiboBufferConfig Configuration for prompt buffers
---@field console? AiboBufferConfig Configuration for console buffers
---@field tools? table<string, AiboBufferConfig> Tool-specific configurations, keyed by the tool name aibo dispatches on (the first word of the invoked command, e.g. "claude", "codex", "gemini")
---@field submit_key? string Key to submit input (default: "<CR>")
---@field submit_delay? integer Delay before submit in ms (default: 500)
---@field prompt_height? integer Height of prompt window (default: 10)
---@field prompt_blend? integer (deprecated) Prompt window transparency, used as fallback for prompt_blend_insert/prompt_blend_normal
---@field prompt_blend_insert? integer Prompt window transparency in Insert mode 0-100 (default: 10)
---@field prompt_blend_normal? integer Prompt window transparency in Normal mode 0-100 (default: 30)
---@field prompt_title? string Prompt window title (default: " Ctrl+Enter: Submit | Esc: Close | Ctrl+C: Cancel ")
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
  -- Tool-specific configurations, keyed by the tool name aibo dispatches on
  -- (the first word of the invoked command). `completion` here selects which
  -- completion module backs that tool's "/" completion -- see
  -- AiboCompletionConfig and completion/prompt_ftplugin.lua. All on by
  -- default: none of claude/codex/acp has a static fallback, so disabling
  -- one leaves no "/" completion at all for that tool.
  tools = {
    claude = {
      completion = { claude = true }, -- direct probe of `claude` (does not speak ACP itself)
    },
    codex = {
      completion = { codex = true }, -- direct probe of `codex` (does not speak ACP itself)
    },
    gemini = {
      -- Generic ACP client (completion/acp.lua): Gemini CLI speaks ACP
      -- natively (`gemini --acp`).
      completion = { acp = true },
    },
  },
  submit_key = "<CR>",
  submit_delay = 500,
  prompt_height = 10,
  prompt_blend_insert = 10,
  prompt_blend_normal = 30,
  prompt_title = " Ctrl+Enter: Submit | Esc: Close | Ctrl+C: Cancel ",
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
  -- Backward compatibility: prompt_blend as fallback for mode-specific values
  if config.prompt_blend ~= nil then
    if config.prompt_blend_insert == nil then
      config.prompt_blend_insert = config.prompt_blend
    end
    if config.prompt_blend_normal == nil then
      config.prompt_blend_normal = config.prompt_blend
    end
  end
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

---Get a tool's configuration for a specific completion source. Completion
---config lives under `tools.<tool>.completion.<source>` -- e.g. the `claude`
---tool's own `claude` probe is `tools.claude.completion.claude`, and the
---`gemini` tool's generic ACP client is `tools.gemini.completion.acp`.
---@param tool string Tool name (e.g., "claude", "codex", "gemini")
---@param source string Completion module name (e.g., "claude", "codex", "acp")
---@return AiboProbeConfig|boolean Configuration for the source (false when disabled/unset)
function M.get_completion_config(tool, source)
  local tool_completion = tool and config.tools and config.tools[tool] and config.tools[tool].completion
  if tool_completion and tool_completion[source] ~= nil then
    local value = tool_completion[source]
    if type(value) == "table" then
      return vim.deepcopy(value)
    end
    return value
  end
  return false
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
