local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

T["enter forwards captured keys to send_fn and exits on <Esc> without forwarding it"] = function()
  local direct_mode = require("aibo.internal.direct_mode")

  local console_bufnr = vim.api.nvim_create_buf(false, true)
  local console_winid = vim.api.nvim_open_win(console_bufnr, true, {
    relative = "editor",
    width = 80,
    height = 24,
    row = 0,
    col = 0,
  })

  local calls = 0
  local indicator_seen_open = false
  local indicator_title = nil
  local original_getchar = vim.fn.getchar
  vim.fn.getchar = function()
    calls = calls + 1
    if calls == 1 then
      local indicator_winid = direct_mode._active_indicators[console_winid]
      indicator_seen_open = indicator_winid ~= nil and vim.api.nvim_win_is_valid(indicator_winid)
      if indicator_seen_open then
        indicator_title = vim.api.nvim_win_get_config(indicator_winid).title[1][1]
      end
      return string.byte("a")
    end
    return 27 -- <Esc>
  end

  local sent = {}
  direct_mode.enter(console_winid, function(key)
    table.insert(sent, key)
  end)

  vim.fn.getchar = original_getchar

  eq(indicator_seen_open, true)
  eq(indicator_title, " Direct mode ")
  eq(sent, { "a" })
  eq(direct_mode._active_indicators[console_winid], nil)

  vim.api.nvim_win_close(console_winid, true)
end

T["enter exits immediately when the first key is <Esc>"] = function()
  local direct_mode = require("aibo.internal.direct_mode")

  local console_bufnr = vim.api.nvim_create_buf(false, true)
  local console_winid = vim.api.nvim_open_win(console_bufnr, true, {
    relative = "editor",
    width = 80,
    height = 24,
    row = 0,
    col = 0,
  })

  local original_getchar = vim.fn.getchar
  vim.fn.getchar = function()
    return 27 -- <Esc>
  end

  local sent = {}
  direct_mode.enter(console_winid, function(key)
    table.insert(sent, key)
  end)

  vim.fn.getchar = original_getchar

  eq(sent, {})
  eq(direct_mode._active_indicators[console_winid], nil)

  vim.api.nvim_win_close(console_winid, true)
end

T["enter hides a visible prompt window and reopens it after exiting"] = function()
  local direct_mode = require("aibo.internal.direct_mode")
  local prompt = require("aibo.internal.prompt_window")
  local console = require("aibo.internal.console_window")

  local console_bufnr = vim.api.nvim_create_buf(false, true)
  local console_winid = vim.api.nvim_open_win(console_bufnr, true, {
    relative = "editor",
    width = 80,
    height = 24,
    row = 0,
    col = 0,
  })

  local original_get_info = console.get_info_by_winid
  console.get_info_by_winid = function(winid)
    return {
      winid = winid,
      bufnr = console_bufnr,
      bufname = "aiboconsole://test//",
      jobinfo = { cmd = "test", args = {}, job_id = 42 },
    }
  end

  local prompt_info = prompt.open(console_winid, { startinsert = false })
  local prompt_bufnr = prompt_info.bufnr

  local prompt_winid_during_direct = nil
  local original_getchar = vim.fn.getchar
  vim.fn.getchar = function()
    prompt_winid_during_direct = prompt.get_info_by_console_winid(console_winid)
    return 27 -- <Esc>
  end

  direct_mode.enter(console_winid, function() end)

  vim.fn.getchar = original_getchar

  -- The prompt window was closed for the duration of Direct mode; the buffer
  -- itself survives (bufhidden=hide) but no window shows it (winid == -1).
  eq(prompt_winid_during_direct ~= nil, true)
  eq(prompt_winid_during_direct.winid, -1)

  -- ...and reopened (same buffer) once Direct mode exited.
  local reopened = prompt.get_info_by_console_winid(console_winid)
  eq(reopened ~= nil, true)
  eq(reopened.bufnr, prompt_bufnr)
  eq(vim.api.nvim_win_is_valid(reopened.winid), true)

  console.get_info_by_winid = original_get_info
  vim.api.nvim_win_close(console_winid, true)
end

T["enter does nothing prompt-related when no prompt window is visible"] = function()
  local direct_mode = require("aibo.internal.direct_mode")
  local prompt = require("aibo.internal.prompt_window")

  local console_bufnr = vim.api.nvim_create_buf(false, true)
  local console_winid = vim.api.nvim_open_win(console_bufnr, true, {
    relative = "editor",
    width = 80,
    height = 24,
    row = 0,
    col = 0,
  })

  local original_getchar = vim.fn.getchar
  vim.fn.getchar = function()
    return 27 -- <Esc>
  end

  direct_mode.enter(console_winid, function() end)

  vim.fn.getchar = original_getchar

  eq(prompt.get_info_by_console_winid(console_winid), nil)

  vim.api.nvim_win_close(console_winid, true)
end

return T
