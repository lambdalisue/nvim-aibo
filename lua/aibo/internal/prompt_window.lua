--- Prompt window management module for AI agent interaction.
---
--- This module provides a text input interface for communicating with AI agents
--- running in console windows. It handles:
--- - Prompt buffer creation and lifecycle management
--- - Input submission to associated console terminals
--- - Bidirectional window synchronization with consoles
--- - Key mappings for terminal control from prompt
---
--- Buffer naming scheme:
---   aiboprompt://CONSOLE_WINDOW_ID
---   Example: aiboprompt://1234
---
--- Integration with console windows:
---   - Auto-opens when focusing console (TermEnter)
---   - Auto-closes when console closes (WinClosed)
---   - Submits input via :write command (BufWriteCmd)
---
--- @alias PromptInfo table Prompt information object with fields:
---   winid (number), bufnr (number), bufname (string), console_info (table)
local M = {}
local PREFIX = "aiboprompt://"

---@param bufname string
---@return number? console_winid or nil if not a valid prompt buffer
local function parse_bufname(bufname)
  local console_winid = string.match(bufname, "^" .. vim.pesc(PREFIX) .. "(%d+)$")
  if console_winid then
    return tonumber(console_winid)
  else
    return nil
  end
end

---@param partial { winid?: number, bufnr?: number, bufname?: string }
---@return nil or {
---  winid: number,
---  bufnr: number,
---  bufname: string,
---  console_info: nil or {
---    winid: number,
---    bufnr: number,
---    jobinfo: {
---      cmd: string,
---      args: string[],
---      job_id: number,
---    },
---  }
--- } Complete info or nil if invalid
local function build_info(partial)
  local console = require("aibo.internal.console_window")

  local winid = partial.winid
  local bufnr = partial.bufnr
  local bufname
  if winid then
    if not vim.api.nvim_win_is_valid(winid) then
      return nil
    end
    bufnr = bufnr or vim.api.nvim_win_get_buf(winid)
    bufname = partial.bufname or vim.api.nvim_buf_get_name(bufnr)
  elseif bufnr then
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return nil
    end
    winid = winid or vim.fn.bufwinid(bufnr)
    bufname = partial.bufname or vim.api.nvim_buf_get_name(bufnr)
  else
    error("[aibo] Either winid or bufnr must be provided")
  end
  if string.sub(bufname, 1, #PREFIX) ~= PREFIX then
    return nil
  end
  local console_info = nil
  local console_winid = parse_bufname(bufname)
  if console_winid then
    console_info = console.get_info_by_winid(console_winid)
  end
  return {
    winid = winid,
    bufnr = bufnr,
    bufname = bufname,
    console_info = console_info,
  }
end

---@param bufnr number Buffer number
local function setup_mappings(bufnr)
  local aibo = require("aibo")
  local console = require("aibo.internal.console_window")

  local define = function(lhs, desc, rhs)
    vim.keymap.set({ "n", "i" }, lhs, rhs, {
      buffer = bufnr,
      desc = desc,
      silent = true,
    })
  end

  local send = function(key)
    local winid = vim.api.nvim_get_current_win()
    local info = M.get_info_by_winid(winid)
    if info and info.console_info then
      local code = aibo.termcode.resolve(key)
      console.send(info.console_info.bufnr, code)
    end
  end

  define("<Plug>(aibo-prompt-submit)", "Submit prompt to associated console", function()
    vim.cmd("write")
  end)
  define("<Plug>(aibo-prompt-submit-close)", "Submit prompt to associated console then close", function()
    vim.cmd("wq")
  end)
  define("<Plug>(aibo-prompt-esc)", "Send ESC to associated console", function()
    send("<Esc>")
  end)
  define("<Plug>(aibo-prompt-interrupt)", "Send interrupt signal (original <C-c>) to associated console", function()
    send("<C-c>")
  end)
  define("<Plug>(aibo-prompt-clear)", "Clear screen in associated console", function()
    send("<C-l>")
  end)
  define("<Plug>(aibo-prompt-next)", "Next history in associated console", function()
    send("<C-n>")
  end)
  define("<Plug>(aibo-prompt-prev)", "Previous history in associated console", function()
    send("<C-p>")
  end)
  define("<Plug>(aibo-prompt-down)", "Move down in associated console", function()
    send("<Down>")
  end)
  define("<Plug>(aibo-prompt-up)", "Move up in associated console", function()
    send("<Up>")
  end)
end

---@param ev { buf: number, file: string }
local function BufWritePre(ev)
  vim.bo[ev.buf].modified = true
end

---@param ev { buf: number, file: string }
local function BufWriteCmd(ev)
  local info = M.get_info_by_bufnr(ev.buf)
  if not info then
    return
  end
  M.submit(info.bufnr)
end

local function WinLeave()
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_hide(winid)
end

local function QuitPre()
  local bufinfos = vim.fn.getbufinfo({ bufloaded = 1 })
  for _, bufinfo in ipairs(bufinfos) do
    if string.sub(bufinfo.name, 1, #PREFIX) == PREFIX then
      vim.bo[bufinfo.bufnr].modified = false
    end
  end
end

--- Get prompt window information by buffer number.
--- Retrieves complete information about a prompt buffer including its window
--- and associated console details.
---
--- @param bufnr number The prompt buffer number to query
--- @return nil|table Returns nil if buffer is invalid, otherwise returns:
---   - winid: number - Window ID displaying the prompt (-1 if not displayed)
---   - bufnr: number - The prompt buffer number
---   - bufname: string - Full buffer name (aiboprompt://console_winid)
---   - console_info: table|nil - Associated console information if valid:
---     - winid: number - Console window ID
---     - bufnr: number - Console buffer number
---     - jobinfo: table - Terminal job details
---
--- @usage
---   local prompt = require("aibo.internal.prompt_window")
---   local info = prompt.get_info_by_bufnr(vim.api.nvim_get_current_buf())
---   if info and info.console_info then
---     print("Prompt for: " .. info.console_info.jobinfo.cmd)
---   end
function M.get_info_by_bufnr(bufnr)
  return build_info({ bufnr = bufnr })
end

--- Get prompt window information by window ID.
--- Retrieves complete information about a prompt displayed in a specific window.
---
--- @param winid number The window ID to query
--- @return nil|table Returns nil if window is invalid, otherwise returns:
---   - winid: number - The prompt window ID
---   - bufnr: number - Prompt buffer number in the window
---   - bufname: string - Full buffer name (aiboprompt://console_winid)
---   - console_info: table|nil - Associated console information if valid:
---     - winid: number - Console window ID
---     - bufnr: number - Console buffer number
---     - jobinfo: table - Terminal job details
---
--- @usage
---   local prompt = require("aibo.internal.prompt_window")
---   local info = prompt.get_info_by_winid(vim.api.nvim_get_current_win())
---   if info then
---     vim.api.nvim_buf_set_lines(info.bufnr, 0, -1, false, {"New prompt"})
---   end
function M.get_info_by_winid(winid)
  return build_info({ winid = winid })
end

--- Get prompt window information by its associated console window ID.
--- Searches for a prompt buffer that is linked to a specific console window.
---
--- @param console_winid number The console window ID to search for
--- @return nil|table Returns nil if no prompt found, otherwise returns:
---   - winid: number - Prompt window ID (-1 if not displayed)
---   - bufnr: number - Prompt buffer number
---   - bufname: string - Full buffer name (aiboprompt://console_winid)
---   - console_info: table|nil - Associated console information if valid:
---     - winid: number - Console window ID
---     - bufnr: number - Console buffer number
---     - jobinfo: table - Terminal job details
---
--- @usage
---   local prompt = require("aibo.internal.prompt_window")
---   -- Find prompt for console window 1234
---   local info = prompt.get_info_by_console_winid(1234)
---   if info then
---     if info.winid ~= -1 then
---       vim.api.nvim_set_current_win(info.winid)
---     end
---   end
function M.get_info_by_console_winid(console_winid)
  local bufname = string.format("%s%s", PREFIX, console_winid)
  local bufnr = vim.fn.bufnr(bufname)
  if bufnr == -1 then
    return nil
  end
  return build_info({ bufnr = bufnr, bufname = bufname })
end

--- Find prompt window information in the current tabpage
function M.find_info_in_tabpage()
  local console = require("aibo.internal.console_window")
  -- We need to find the console window first while prompt windows are hidden
  -- and the console window is the main entry point for aibo
  local console_info = console.find_info_in_tabpage()
  if not console_info then
    return nil
  end
  return M.get_info_by_console_winid(console_info.winid)
end

--- Open or reopen a prompt window for a console.
--- Creates a new prompt buffer or reuses an existing one. The prompt window
--- is opened relative to its associated console window. Writing the buffer
--- (`:w`) submits its contents to the console.
---
--- @param console_winid number The console window ID to attach to
--- @param options? table Optional configuration:
---   - opener?: string - Window command (default: "rightbelow 10split")
---                       Examples: "split", "vsplit", "leftabove split"
---   - startinsert?: boolean - Enter insert mode after opening (default: true)
--- @return nil|table Returns nil on failure, otherwise returns:
---   - winid: number - Prompt window ID
---   - bufnr: number - Prompt buffer number
---   - bufname: string - Full buffer name (aiboprompt://console_winid)
---   - console_info: table - Associated console information:
---     - winid: number - Console window ID
---     - bufnr: number - Console buffer number
---     - jobinfo: table - Terminal job details
---
--- @usage
---   local prompt = require("aibo.internal.prompt_window")
---   -- Open prompt below console
---   local prompt_info = prompt.open(console_winid, {
---     opener = "below 5split",
---     startinsert = true
---   })
---
---   -- Type and submit with :w
---   vim.api.nvim_buf_set_lines(prompt_info.bufnr, 0, -1, false, {
---     "Hello, AI assistant!"
---   })
function M.open(console_winid, options)
  local aibo = require("aibo")
  local integration = require("aibo.integration")
  local console = require("aibo.internal.console_window")

  local console_info = console.get_info_by_winid(console_winid)
  if not console_info then
    vim.notify(
      string.format("Failed to find a valid console info from winid %d", console_winid),
      vim.log.levels.ERROR,
      { title = "Aibo prompt" }
    )
    return nil
  end

  options = options or {}
  local config = aibo.get_config()
  local opener = options.opener or string.format("rightbelow %dsplit", config.prompt_height)

  -- Check if the prompt window for the console already exists
  local bufname = string.format("%s%s", PREFIX, console_winid)
  local bufnr = vim.fn.bufnr(bufname)
  local winid = vim.fn.bufwinid(bufnr)
  if winid == -1 then
    -- The prompt buffer is not displayed in any window in the current tabpage, open it
    vim.api.nvim_win_call(console_winid, function()
      vim.cmd(string.format("silent %s %s", opener, vim.fn.fnameescape(bufname)))
      winid = vim.api.nvim_get_current_win()
      bufnr = vim.api.nvim_get_current_buf()
    end)
    vim.api.nvim_set_current_win(winid)
  end

  setup_mappings(bufnr)
  integration.setup_mappings(console_info.jobinfo.cmd, bufnr)
  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = string.format("aibo-prompt.aibo-tool-%s", console_info.jobinfo.cmd)

  local info = {
    type = "prompt",
    cmd = console_info.jobinfo.cmd,
    args = console_info.jobinfo.args,
    job_id = console_info.jobinfo.job_id,
  }
  local buffer_cfg = aibo.get_buffer_config("prompt")
  if buffer_cfg.on_attach then
    buffer_cfg.on_attach(bufnr, info)
  end
  local tool_cfg = aibo.get_tool_config(console_info.cmd)
  if tool_cfg.on_attach then
    tool_cfg.on_attach(bufnr, info)
  end

  -- Start insert mode
  if options.startinsert then
    vim.defer_fn(function()
      if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_get_current_win() == winid then
        vim.cmd("startinsert")
      end
    end, 0)
  end

  return {
    winid = winid,
    bufnr = bufnr,
    bufname = bufname,
    console_info = console_info,
  }
end

-- Write input to a prompt buffer.
-- Inserts or replaces text in the specified prompt buffer.
---@param bufnr number The prompt buffer number to modify
---@param content string[] The text to insert (string or list of lines)
---@param options? table Optional configuration:
---  - replace?: boolean - If true, replaces entire buffer content (default: false)
---@return boolean|nil Returns true on success, nil if buffer is invalid
function M.write(bufnr, content, options)
  if M.get_info_by_bufnr(bufnr) == nil then
    vim.notify(
      string.format("Buffer %d is not a valid prompt buffer", bufnr),
      vim.log.levels.ERROR,
      { title = "Aibo prompt Error" }
    )
    return nil
  end

  options = options or {}

  local replace = options.replace or false
  if replace then
    -- Replace
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
  else
    local existing = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    if #existing == 1 and existing[1] == "" then
      -- Replace
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
    else
      -- Append
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, content)
    end
  end

  return true
end

-- Submit the contents of a prompt buffer to its associated console.
---@param bufnr number The prompt buffer number to submit
---@return nil Returns nil if buffer is invalid or submission fails
function M.submit(bufnr)
  local console = require("aibo.internal.console_window")

  local info = M.get_info_by_bufnr(bufnr)
  if not info or not info.console_info then
    vim.notify(
      string.format("Buffer %d is not a valid prompt buffer", bufnr),
      vim.log.levels.ERROR,
      { title = "Aibo prompt Error" }
    )
    return nil
  end

  local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  vim.defer_fn(function()
    local b = info.console_info.bufnr
    if vim.api.nvim_buf_is_valid(b) then
      console.submit(b, content)
    end
  end, 0)

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.bo[bufnr].modified = false
  -- The prompt window may be hidden, so we need to check if it's valid
  if vim.api.nvim_win_is_valid(info.winid) then
    vim.api.nvim_win_set_cursor(info.winid, { 1, 0 })
  end
end

-- Global autocmd for QuitPre
local augroup = vim.api.nvim_create_augroup("aibo_prompt_internal", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  pattern = string.format("%s*", PREFIX),
  nested = false,
  callback = BufWritePre,
})
vim.api.nvim_create_autocmd("BufWriteCmd", {
  group = augroup,
  pattern = string.format("%s*", PREFIX),
  nested = true,
  callback = BufWriteCmd,
})
vim.api.nvim_create_autocmd("WinLeave", {
  group = augroup,
  pattern = string.format("%s*", PREFIX),
  nested = true,
  callback = WinLeave,
})
vim.api.nvim_create_autocmd("QuitPre", {
  group = augroup,
  pattern = "*", -- We'd like to catch all QuitPre events
  nested = false,
  callback = QuitPre,
})

return M
