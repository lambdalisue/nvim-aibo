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
local M = {}
local PREFIX = "aiboprompt"

--- Registry of active prompt windows for efficient VimResized handling.
--- Maps prompt window ID to its parent console window ID.
local active_prompt_wins = {}

---@alias PromptInfo { winid: number, bufnr: number, bufname: string, console_info: ConsoleInfo? }

---@param bufname string
---@return number? console_winid or nil if not a valid prompt buffer
local function parse_bufname(bufname)
  local bufname_module = require("aibo.internal.bufname")
  local scheme, components = bufname_module.decode(bufname)
  if scheme ~= PREFIX then
    return nil
  end
  -- components[1]: console_winid
  if components[1] and components[1] ~= "" then
    return tonumber(components[1])
  end
  return nil
end

---@param partial { winid?: number, bufnr?: number, bufname?: string }
---@return PromptInfo? Complete info or nil if invalid
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
  local bufname_module = require("aibo.internal.bufname")
  local scheme, _ = bufname_module.decode(bufname)
  if scheme ~= PREFIX then
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

local highlights_initialized = false

local function setup_highlights()
  vim.api.nvim_set_hl(0, "AiboPromptNormal", { default = true, link = "Normal" })
  vim.api.nvim_set_hl(0, "AiboPromptBorder", { default = true, link = "DiagnosticInfo" })
  vim.api.nvim_set_hl(0, "AiboPromptTitle", { default = true, link = "DiagnosticInfo" })
  vim.api.nvim_set_hl(0, "AiboPromptInsertBorder", { default = true, link = "DiagnosticWarn" })
  vim.api.nvim_set_hl(0, "AiboPromptInsertTitle", { default = true, link = "DiagnosticWarn" })
end

--- Ensure prompt highlight groups are defined (once per session).
--- Deferred from plugin/ load time to avoid colorscheme timing issues.
--- Also registers a ColorScheme autocmd for future colorscheme changes.
local function ensure_highlights()
  if highlights_initialized then
    return
  end
  highlights_initialized = true
  setup_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("aibo_highlights", { clear = true }),
    callback = setup_highlights,
  })
end

--- Apply mode-specific highlights and winblend to prompt window.
--- In Insert mode, uses AiboPromptInsertBorder/Title and lower winblend (more opaque).
--- In Normal mode, uses AiboPromptBorder/Title and higher winblend (more transparent).
---@param winid number Window ID
---@param mode "insert"|"normal" Current mode
local function apply_mode_style(winid, mode)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end
  local aibo = require("aibo")
  local config = aibo.get_config()
  if mode == "insert" then
    vim.wo[winid].winhighlight =
      "NormalFloat:AiboPromptNormal,FloatBorder:AiboPromptInsertBorder,FloatTitle:AiboPromptInsertTitle"
    vim.wo[winid].winblend = config.prompt_blend_insert or 10
  else
    vim.wo[winid].winhighlight = "NormalFloat:AiboPromptNormal,FloatBorder:AiboPromptBorder,FloatTitle:AiboPromptTitle"
    vim.wo[winid].winblend = config.prompt_blend_normal or 30
  end
end

--- Set up autocmds for mode-dependent prompt window styling.
--- Only creates autocmds once per buffer (tracked via buffer variable).
---@param bufnr number Buffer number
local function setup_mode_autocmds(bufnr)
  if vim.b[bufnr].aibo_prompt_mode_autocmds then
    return
  end
  vim.b[bufnr].aibo_prompt_mode_autocmds = true

  local mode_augroup = vim.api.nvim_create_augroup("aibo_prompt_mode_" .. bufnr, { clear = true })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = mode_augroup,
    buffer = bufnr,
    callback = function()
      local wid = vim.fn.bufwinid(bufnr)
      if wid ~= -1 then
        apply_mode_style(wid, "insert")
      end
    end,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = mode_augroup,
    buffer = bufnr,
    callback = function()
      local wid = vim.fn.bufwinid(bufnr)
      if wid ~= -1 then
        apply_mode_style(wid, "normal")
      end
    end,
  })

  -- WORKAROUND: Reassign winblend on text/cursor changes to fix rendering
  -- glitches that occur when the Console is running in the background.
  -- Symptoms include gaps in rendering and deleted characters remaining
  -- visible. It is unclear whether this truly fixes the issue.
  -- Trying this workaround since 2026-02-14.
  vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
    group = mode_augroup,
    buffer = bufnr,
    callback = function()
      local wid = vim.fn.bufwinid(bufnr)
      if wid == -1 or not vim.api.nvim_win_is_valid(wid) then
        return
      end
      local current = vim.wo[wid].winblend
      vim.wo[wid].winblend = current
    end,
  })
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
      local code = aibo.resolve(key) or key
      console.send(info.console_info.bufnr, code)
    end
  end

  define("<Plug>(aibo-send)", "Get one key from user and send it to associated console", function()
    local keycode = require("aibo.internal.keycode")
    local key = keycode.get_single_keycode({ prompt = "Oneshot (press any key): ", highlight = "MoreMsg" })
    if key then
      send(key)
    end
  end)
  define("<Plug>(aibo-submit)", "Submit prompt to associated console", function()
    vim.cmd("write")
  end)

  -- History navigation mappings
  local history = require("aibo.internal.history")

  local function set_buffer_and_cursor(lines)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    -- Move cursor to end of buffer
    local last_line = #lines
    local last_col = #lines[last_line]
    vim.api.nvim_win_set_cursor(0, { last_line, last_col })
  end

  define("<Plug>(aibo-history-prev)", "Navigate to previous history entry", function()
    local lines = history.prev(bufnr)
    if lines then
      set_buffer_and_cursor(lines)
    end
  end)

  define("<Plug>(aibo-history-next)", "Navigate to next history entry", function()
    local lines = history.next(bufnr)
    if lines then
      set_buffer_and_cursor(lines)
    end
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
  if vim.api.nvim_win_is_valid(winid) then
    local win_config = vim.api.nvim_win_get_config(winid)
    -- Only auto-close floating windows to avoid conflicts with explicit :q/<Esc>
    if win_config.relative and win_config.relative ~= "" then
      pcall(vim.api.nvim_win_close, winid, false)
    end
  end
end

local function QuitPre()
  local bufname_module = require("aibo.internal.bufname")
  local bufinfos = vim.fn.getbufinfo({ bufloaded = 1 })
  for _, bufinfo in ipairs(bufinfos) do
    local scheme, _ = bufname_module.decode(bufinfo.name)
    if scheme == PREFIX then
      vim.bo[bufinfo.bufnr].modified = false
    end
  end
end

--- Get prompt window information by buffer number.
--- Retrieves complete information about a prompt buffer including its window
--- and associated console details.
---
--- @param bufnr number The prompt buffer number to query
--- @return PromptInfo?
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
--- @return PromptInfo?
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
--- @return PromptInfo?
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
  local bufname_module = require("aibo.internal.bufname")
  local bufname = bufname_module.encode(PREFIX, { tostring(console_winid) })
  local bufnr = vim.fn.bufnr(bufname)
  if bufnr == -1 then
    return nil
  end
  return build_info({ bufnr = bufnr, bufname = bufname })
end

--- Find prompt window information in the current tabpage
---@return PromptInfo?
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

--- Compute geometry-only float config for a prompt window.
--- Returns position and size properties relative to the given console window.
---@param console_winid number The parent console window ID
---@param config table Plugin config (used for prompt_height)
---@return table Float config with relative, win, row, col, width, height
local function compute_float_config(console_winid, config)
  local console_height = vim.api.nvim_win_get_height(console_winid)
  local console_width = vim.api.nvim_win_get_width(console_winid)
  local prompt_height = config.prompt_height or 10
  -- Clamp prompt_height to fit within console (account for border which takes 2 rows)
  prompt_height = math.min(prompt_height, math.max(1, console_height - 2))
  -- Position at bottom with border space; ensure row is never negative
  local row = math.max(0, console_height - prompt_height - 2)
  return {
    relative = "win",
    win = console_winid,
    row = row,
    col = 0,
    width = math.max(1, console_width - 2), -- Account for rounded border
    height = prompt_height,
  }
end

--- Build complete float config with both geometry and style properties.
--- Used by M.open (initial creation) and VimResized (reposition) to ensure
--- all window properties are consistently set.
---@param console_winid number The parent console window ID
---@param config table Plugin config
---@return table Complete float config for nvim_open_win / nvim_win_set_config
local function make_full_float_config(console_winid, config)
  local float_config = compute_float_config(console_winid, config)
  float_config.style = "minimal"
  float_config.border = "rounded"
  float_config.title = config.prompt_title or " Ctrl+Enter: Submit | Esc: Close | Ctrl+C: Cancel "
  float_config.title_pos = "right"
  float_config.focusable = true
  float_config.zindex = 49
  return float_config
end

--- Open or reopen a prompt window for a console.
--- Creates a new prompt buffer or reuses an existing one. The prompt window
--- is opened as a floating window at the bottom of the console window.
--- Writing the buffer (`:w`) submits its contents to the console.
---
--- @param console_winid number The console window ID to attach to
--- @param options? table Optional configuration:
---   - startinsert?: boolean - Enter insert mode after opening (default: true)
--- @return PromptInfo?
---
--- @usage
---   local prompt = require("aibo.internal.prompt_window")
---   -- Open prompt as floating window
---   local prompt_info = prompt.open(console_winid, {
---     startinsert = true
---   })
---
---   -- Type and submit with :w
---   vim.api.nvim_buf_set_lines(prompt_info.bufnr, 0, -1, false, {
---     "Hello, AI assistant!"
---   })
function M.open(console_winid, options)
  ensure_highlights()
  local aibo = require("aibo")
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

  -- Check if the prompt window for the console already exists
  local bufname_module = require("aibo.internal.bufname")
  local bufname = bufname_module.encode(PREFIX, { tostring(console_winid) })
  local bufnr = vim.fn.bufnr(bufname)

  -- Create buffer if it doesn't exist
  if bufnr == -1 then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, bufname)
  end

  -- Check if window already exists
  local winid = vim.fn.bufwinid(bufnr)
  if winid == -1 then
    -- Create floating window
    local float_config = make_full_float_config(console_winid, config)
    winid = vim.api.nvim_open_win(bufnr, true, float_config)
    active_prompt_wins[winid] = console_winid
  else
    -- Window already exists, just focus it
    vim.api.nvim_set_current_win(winid)
  end

  -- Apply mode style based on initial mode:
  -- if options.startinsert is true, we expect to enter insert mode immediately,
  -- so apply insert styling up front to avoid a normal→insert flicker.
  local initial_mode = (options and options.startinsert) and "insert" or "normal"
  apply_mode_style(winid, initial_mode)
  setup_mode_autocmds(bufnr)
  setup_mappings(bufnr)
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
        vim.cmd("startinsert!")
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
  local history = require("aibo.internal.history")

  local info = M.get_info_by_bufnr(bufnr)
  if not info or not info.console_info then
    vim.notify(
      string.format("Buffer %d is not a valid prompt buffer", bufnr),
      vim.log.levels.ERROR,
      { title = "Aibo prompt Error" }
    )
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  -- Add to history before clearing
  history.add(content)
  history.clear_state(bufnr)

  vim.defer_fn(function()
    local b = info.console_info.bufnr
    if vim.api.nvim_buf_is_valid(b) then
      console.submit(b, content)
      console.follow(b)
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
  pattern = string.format("%s://*", PREFIX),
  nested = false,
  callback = BufWritePre,
})
vim.api.nvim_create_autocmd("BufWriteCmd", {
  group = augroup,
  pattern = string.format("%s://*", PREFIX),
  nested = true,
  callback = BufWriteCmd,
})
vim.api.nvim_create_autocmd("WinLeave", {
  group = augroup,
  pattern = string.format("%s://*", PREFIX),
  nested = true,
  callback = WinLeave,
})
vim.api.nvim_create_autocmd("QuitPre", {
  group = augroup,
  pattern = "*", -- We'd like to catch all QuitPre events
  nested = false,
  callback = QuitPre,
})
vim.api.nvim_create_autocmd("VimResized", {
  group = augroup,
  callback = function()
    local aibo = require("aibo")
    local config = aibo.get_config()
    for winid, console_winid in pairs(active_prompt_wins) do
      if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_is_valid(console_winid) then
        local new_config = make_full_float_config(console_winid, config)
        vim.api.nvim_win_set_config(winid, new_config)
      else
        active_prompt_wins[winid] = nil
      end
    end
  end,
})

-- Exposed for testing only
M._compute_float_config = compute_float_config
M._active_prompt_wins = active_prompt_wins

return M
