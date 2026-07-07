--- Direct mode: continuously forward key presses to a console's tool.
---
--- Unlike the one-shot `<Plug>(aibo-send)` capture (which sends a single key
--- and returns immediately), Direct mode repeats the capture until <Esc> is
--- pressed. <Esc> itself is never forwarded -- it always exits Direct mode,
--- consistent with the rest of Aibo where the physical <Esc> key is reserved
--- for Vim and never sent to the tool as a raw byte.
---
--- While active, a fixed 5-line floating window is shown at the top of the
--- console explaining the mode and how to exit it. If a prompt window is
--- currently visible for the console, it is hidden for the duration and
--- reopened (in the same Normal/Insert state) once Direct mode ends.
local M = {}

local TITLE = " Direct mode "
local HEIGHT = 5
local CONTENT = {
  "Direct mode forwards every key you press",
  "directly to the tool.",
  "",
  "  <Esc>   Exit Direct mode",
  "  <C-c>   Send ESC to the tool",
}

-- Thick border, as opposed to the thin "rounded" border used elsewhere.
local BORDER = { "┏", "━", "┓", "┃", "┛", "━", "┗", "┃" }

--- Registry of indicator windows currently shown, keyed by console winid.
--- Exposed for testing only.
local active_indicators = {}

---@param console_winid number
---@return number indicator winid
local function open_indicator(console_winid)
  local prompt = require("aibo.internal.prompt_window")
  prompt.ensure_highlights()

  local width = vim.api.nvim_win_get_width(console_winid)

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, CONTENT)
  vim.bo[bufnr].modifiable = false

  local winid = vim.api.nvim_open_win(bufnr, false, {
    relative = "win",
    win = console_winid,
    row = 0,
    col = 0,
    width = math.max(1, width - 2),
    height = HEIGHT,
    style = "minimal",
    border = BORDER,
    title = TITLE,
    title_pos = "left",
    focusable = false,
    zindex = 200,
  })
  vim.wo[winid].winhighlight = "FloatBorder:AiboDirectBorder,FloatTitle:AiboDirectTitle"
  return winid
end

---@param winid number?
local function close_indicator(winid)
  if winid and vim.api.nvim_win_is_valid(winid) then
    pcall(vim.api.nvim_win_close, winid, true)
  end
end

--- Hide a console's visible prompt window for the duration of Direct mode.
---@param console_winid number
---@return boolean had_prompt True if a prompt window was visible and hidden
---@return boolean was_insert True if the prompt itself was focused in Insert mode
local function hide_prompt(console_winid)
  local prompt = require("aibo.internal.prompt_window")
  local info = prompt.get_info_by_console_winid(console_winid)
  if not info or not vim.api.nvim_win_is_valid(info.winid) then
    return false, false
  end
  local was_insert = vim.api.nvim_get_current_win() == info.winid and vim.fn.mode():match("^[iR]") ~= nil
  pcall(vim.api.nvim_win_close, info.winid, true)
  return true, was_insert
end

---@param console_winid number
---@param was_insert boolean
local function restore_prompt(console_winid, was_insert)
  local prompt = require("aibo.internal.prompt_window")
  prompt.open(console_winid, { startinsert = was_insert })
end

--- Enter Direct mode for a console window.
--- Repeatedly captures a single key and passes it to `send_fn`, until <Esc>
--- is pressed or key capture is interrupted. <Esc> is never forwarded.
---
--- @param console_winid number The console window ID to show the indicator on
--- @param send_fn fun(key: string) Called with each captured key (Vim key notation)
function M.enter(console_winid, send_fn)
  local keycode = require("aibo.internal.keycode")

  local had_prompt, was_insert = hide_prompt(console_winid)
  local indicator_winid = open_indicator(console_winid)
  active_indicators[console_winid] = indicator_winid
  -- Paint the indicator before the first (blocking) getchar() call.
  vim.cmd("redraw")

  local ok, err = pcall(function()
    while true do
      local key = keycode.get_single_keycode()
      if not key or key == "<Esc>" then
        break
      end
      send_fn(key)
      -- The tool's terminal echo of what was just sent arrives
      -- asynchronously; give it a moment to land, then repaint, otherwise
      -- it visibly lags by one keystroke behind what was actually typed.
      vim.wait(50)
      vim.cmd("redraw!")
    end
  end)

  close_indicator(indicator_winid)
  active_indicators[console_winid] = nil
  if had_prompt then
    restore_prompt(console_winid, was_insert)
  end
  if not ok then
    error(err, 0)
  end
end

-- Exposed for testing only
M._active_indicators = active_indicators

return M
