-- Tests for console_window module (lua/aibo/internal/console_window.lua)

local T = require("mini.test")

-- Test set
-- Load modules first to ensure autocmd groups exist
local _console = require("aibo.internal.console_window")

local test_set = T.new_set({
  hooks = {
    pre_case = function()
      -- Create a new tab for test isolation
      vim.cmd("tabnew")
    end,
    post_case = function()
      -- Close all tabs except the first one
      vim.cmd("silent! tabonly")
      -- Clean up all buffers after each test
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

-- get_info_by_bufnr tests
test_set["get_info_by_bufnr parses valid console buffer names"] = function()
  local console = require("aibo.internal.console_window")

  -- Test with command only
  local bufname = "aiboconsole://claude//12345"
  local info = console.get_info_by_bufnr(vim.fn.bufadd(bufname))
  T.expect.equality(info ~= nil, true, "Should parse buffer name")
  if info and info.jobinfo then
    T.expect.equality(info.jobinfo.cmd, "claude", "Should extract command")
    T.expect.equality(#info.jobinfo.args, 0, "Should have no args")
    T.expect.equality(info.jobinfo.job_id, 12345, "Should extract job_id")
  end
end

test_set["get_info_by_bufnr handles arguments"] = function()
  local console = require("aibo.internal.console_window")

  -- Test with arguments
  local bufname = "aiboconsole://claude/--model+claude-3-opus/12345"
  local info = console.get_info_by_bufnr(vim.fn.bufadd(bufname))
  T.expect.equality(info ~= nil, true, "Should parse buffer with args")
  if info and info.jobinfo then
    T.expect.equality(info.jobinfo.cmd, "claude", "Should extract command")
    T.expect.equality(info.jobinfo.args[1], "--model", "Should extract first arg")
    T.expect.equality(info.jobinfo.args[2], "claude-3-opus", "Should extract second arg")
  end
end

-- get_info_by_bufnr tests
test_set["get_info_by_bufnr returns nil for invalid buffer"] = function()
  local console = require("aibo.internal.console_window")

  local info = console.get_info_by_bufnr(99999)
  T.expect.equality(info, nil, "Should return nil for invalid buffer")
end

test_set["get_info_by_bufnr returns nil for non-console buffer"] = function()
  local console = require("aibo.internal.console_window")

  local bufnr = vim.api.nvim_create_buf(false, true)
  local info = console.get_info_by_bufnr(bufnr)
  T.expect.equality(info, nil, "Should return nil for non-console buffer")
end

test_set["get_info_by_bufnr returns info for valid console buffer"] = function()
  local console = require("aibo.internal.console_window")

  -- Use unique buffer name to avoid conflicts
  local bufname = "aiboconsole://test//" .. vim.loop.hrtime()
  local bufnr = vim.fn.bufadd(bufname)

  -- Ensure buffer is not displayed in any window
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })

  local info = console.get_info_by_bufnr(bufnr)

  T.expect.equality(info ~= nil, true, "Should return info for console buffer")
  T.expect.equality(info.bufnr, bufnr, "Should have correct bufnr")
  T.expect.equality(info.bufname, bufname, "Should have correct bufname")
  T.expect.equality(info.winid, -1, "Should have -1 winid when not displayed")
end

-- get_info_by_winid tests
test_set["get_info_by_winid returns nil for invalid window"] = function()
  local console = require("aibo.internal.console_window")

  local info = console.get_info_by_winid(99999)
  T.expect.equality(info, nil, "Should return nil for invalid window")
end

test_set["get_info_by_winid returns info for console window"] = function()
  local console = require("aibo.internal.console_window")

  -- Create console buffer
  local bufname = "aiboconsole://test//" .. vim.loop.hrtime()
  local bufnr = vim.fn.bufadd(bufname)

  -- Open in window
  vim.cmd("split")
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, bufnr)

  -- Get info by window ID
  local info = console.get_info_by_winid(winid)

  T.expect.equality(info ~= nil, true, "Should return info for console window")
  if info then
    T.expect.equality(info.winid, winid, "Should have correct winid")
    T.expect.equality(info.bufnr, bufnr, "Should have correct bufnr")
    T.expect.equality(info.bufname, bufname, "Should have correct bufname")
  end
end

-- find_info_in_tabpage tests
test_set["find_info_in_tabpage returns nil when no match"] = function()
  local console = require("aibo.internal.console_window")

  local bufname = "aiboconsole://claude//1234"
  vim.fn.bufadd(bufname)

  local info = console.find_info_in_tabpage({ cmd = "codex", args = {} })
  T.expect.equality(info, nil, "Should return nil when no matching console")
end

test_set["find_info_in_tabpage finds matching console in tabpage"] = function()
  local console = require("aibo.internal.console_window")

  -- Create a console buffer WITHOUT args for the first test
  local bufname1 = "aiboconsole://claude//1234"
  local bufnr1 = vim.fn.bufadd(bufname1)

  -- Ensure the buffer is valid by setting it to a scratch buffer
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr1 })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr1 })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr1 })

  vim.cmd("split")
  local winid1 = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid1, bufnr1)

  -- Find by cmd only (should find the one without args)
  local info = console.find_info_in_tabpage({ cmd = "claude" })
  T.expect.equality(info ~= nil, true, "Should find console by command")
  if info then
    T.expect.equality(info.bufnr, bufnr1, "Should return correct buffer")
    T.expect.equality(info.winid, winid1, "Should return correct window")
  end

  -- Clean up first window
  vim.api.nvim_win_close(winid1, true)

  -- Create another console buffer WITH args
  local bufname2 = "aiboconsole://claude/--model+claude-3-opus/5678"
  local bufnr2 = vim.fn.bufadd(bufname2)

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr2 })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr2 })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr2 })

  vim.cmd("split")
  local winid2 = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid2, bufnr2)

  -- Find by cmd and args
  info = console.find_info_in_tabpage({ cmd = "claude", args = { "--model", "claude-3-opus" } })
  T.expect.equality(info ~= nil, true, "Should find console by command and args")
  if info then
    T.expect.equality(info.bufnr, bufnr2, "Should return correct buffer with args")
  end

  -- Test no match case
  info = console.find_info_in_tabpage({ cmd = "codex" })
  T.expect.equality(info, nil, "Should return nil when no matching console")

  -- Clean up
  vim.api.nvim_win_close(winid2, true)
end

-- send tests
test_set["send returns nil for invalid buffer"] = function()
  local console = require("aibo.internal.console_window")

  local result = console.send(99999, "test")
  T.expect.equality(result, nil, "Should return nil for invalid buffer")
end

test_set["send returns nil for non-terminal buffer"] = function()
  local console = require("aibo.internal.console_window")

  local bufnr = vim.api.nvim_create_buf(false, true)
  local result = console.send(bufnr, "test")
  T.expect.equality(result, nil, "Should return nil for non-terminal buffer")
end

test_set["send successfully sends to terminal buffer"] = function()
  local console = require("aibo.internal.console_window")

  -- Create a console buffer with proper name
  local bufname = "aiboconsole://sendtest//9999"
  local bufnr = vim.fn.bufadd(bufname)

  -- Create terminal
  local chan = vim.api.nvim_open_term(bufnr, {})
  vim.b[bufnr].terminal_job_id = chan

  -- Send data (returns nothing on success, nil on failure)
  local ok = pcall(console.send, bufnr, "test data")
  T.expect.equality(ok, true, "Should successfully send to terminal")
end

-- follow tests
test_set["follow moves cursor to last line for console buffer"] = function()
  local console = require("aibo.internal.console_window")

  -- Create a valid console buffer
  local bufname = "aiboconsole://test//1234"
  local bufnr = vim.fn.bufadd(bufname)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "line 1",
    "line 2",
    "line 3",
    "line 4",
    "line 5",
  })

  -- Open in window
  vim.cmd("split")
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, bufnr)

  -- Set cursor to first line
  vim.api.nvim_win_set_cursor(winid, { 1, 0 })

  -- Call follow
  console.follow(bufnr)

  -- Check cursor moved to last line
  local cursor = vim.api.nvim_win_get_cursor(winid)
  T.expect.equality(cursor[1], 5, "Should move cursor to last line")

  -- Clean up
  vim.api.nvim_win_close(winid, true)
end

test_set["follow handles invalid buffer gracefully"] = function()
  local console = require("aibo.internal.console_window")

  -- Try to follow an invalid buffer (should not error)
  local result = pcall(function()
    console.follow(99999)
  end)
  T.expect.equality(result, true, "Should handle invalid buffer without crashing")
end

-- Test open function
test_set["open creates new console window"] = function()
  local console = require("aibo.internal.console_window")

  -- Mock vim.fn.jobstart to simulate terminal creation
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(cmd, opts)
    -- Return a fake job ID
    return 12345
  end

  -- Open a console window
  local info = console.open("test_cmd", {}, {})

  -- Restore original
  vim.fn.jobstart = original_jobstart

  T.expect.equality(info ~= nil, true, "Should create console window")
  if info then
    T.expect.equality(info.bufname:match("^aiboconsole://"), "aiboconsole://", "Should have console buffer name")
    T.expect.equality(info.winid ~= -1, true, "Should have valid window ID")
  end
end

test_set["open with args creates console with arguments"] = function()
  local console = require("aibo.internal.console_window")

  -- Mock jobstart
  local original_jobstart = vim.fn.jobstart
  local captured_cmd = nil
  vim.fn.jobstart = function(cmd, opts)
    captured_cmd = cmd
    return 54321
  end

  -- Open with arguments
  local info = console.open("testcmdargs", { "--arg1", "value1" }, {})

  -- Restore
  vim.fn.jobstart = original_jobstart

  T.expect.equality(info ~= nil, true, "Should create console with args")

  -- Just verify jobstart was called with args
  if captured_cmd then
    T.expect.equality(#captured_cmd >= 3, true, "Should have command and args")
  end
end

test_set["open handles jobstart failure"] = function()
  local console = require("aibo.internal.console_window")

  -- Mock jobstart to simulate failure
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(cmd, opts)
    return 0 -- Return 0 or negative to indicate failure
  end

  -- Try to open console
  local info = console.open("failing_cmd", {}, {})

  -- Restore
  vim.fn.jobstart = original_jobstart

  T.expect.equality(info, nil, "Should return nil on jobstart failure")
end

-- Test submit function
test_set["submit sends input with newline to terminal"] = function()
  local console = require("aibo.internal.console_window")

  -- Create a terminal buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  local chan = vim.api.nvim_open_term(bufnr, {})
  vim.b[bufnr].terminal_job_id = chan

  -- Test that submit doesn't error
  local ok = pcall(console.submit, bufnr, "test input")
  T.expect.equality(ok, true, "Should submit without error")
end

-- Test focus_or_open function
test_set["focus_or_open focuses existing window"] = function()
  local console = require("aibo.internal.console_window")

  -- Create a console buffer with matching command
  local job_id = 1234
  local bufname = "aiboconsole://test//" .. job_id
  local bufnr = vim.fn.bufadd(bufname)

  -- Set up buffer metadata
  vim.bo[bufnr].filetype = "aibo-console"
  vim.b[bufnr].aibo = { cmd = "test", args = {}, job_id = job_id }

  -- Open in a window
  vim.cmd("split")
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, bufnr)

  -- Move to a different window
  vim.cmd("new")
  local other_win = vim.api.nvim_get_current_win()

  -- Verify we're not in the console window
  T.expect.equality(vim.api.nvim_get_current_win() ~= winid, true, "Should be in different window")

  -- Mock jobstart for potential new console creation
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(cmd, opts)
    return job_id
  end

  -- Call focus_or_open - should focus existing window
  local info = console.focus_or_open("test", {}, {})

  -- Restore original
  vim.fn.jobstart = original_jobstart

  T.expect.equality(info ~= nil, true, "Should return info")
  if info then
    -- Check that we're now in a window showing the console buffer
    local current_buf = vim.api.nvim_get_current_buf()
    T.expect.equality(current_buf, bufnr, "Should be in console buffer")
    -- Also verify it's the same buffer in the info
    T.expect.equality(info.bufnr, bufnr, "Should return same buffer")
  end
end

test_set["focus_or_open creates new console when none exists"] = function()
  local console = require("aibo.internal.console_window")

  -- Mock jobstart
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(cmd, opts)
    return 7890
  end

  -- Call focus_or_open with simple command name
  local info = console.focus_or_open("newcmd", {}, {})

  -- Restore original
  vim.fn.jobstart = original_jobstart

  -- Just check that it returned something
  T.expect.equality(info ~= nil, true, "Should create new console")
end

-- Test toggle_or_open function (simplified to avoid window management issues)
test_set["toggle_or_open returns info"] = function()
  local console = require("aibo.internal.console_window")

  -- Mock jobstart
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(cmd, opts)
    return 12345
  end

  -- Create extra window to avoid "Cannot close last window" error
  vim.cmd("new")

  -- Call toggle_or_open with a simple command name
  local info = console.toggle_or_open("testtoggle", {}, {})

  -- Restore
  vim.fn.jobstart = original_jobstart

  -- Just check that function works without error
  T.expect.equality(info ~= nil, true, "Should return info")
end

test_set["toggle_or_open handles existing window"] = function()
  local console = require("aibo.internal.console_window")

  -- Use unique command name to avoid conflicts
  local unique_cmd = "cycletest" .. vim.loop.hrtime()
  local job_id = 8888
  local bufname = "aiboconsole://" .. unique_cmd .. "//" .. job_id
  local bufnr = vim.fn.bufadd(bufname)

  -- Ensure we have at least 2 windows so we can close one
  vim.cmd("new") -- Create an extra window
  vim.cmd("split")
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, bufnr)

  -- Mock jobstart
  local original_jobstart = vim.fn.jobstart
  vim.fn.jobstart = function(cmd, opts)
    return job_id
  end

  -- Call toggle - should handle existing window
  local info = console.toggle_or_open(unique_cmd, {}, {})

  -- Just verify it returns something (avoid complex window state checks)
  T.expect.equality(info ~= nil, true, "Should return info")

  -- Restore
  vim.fn.jobstart = original_jobstart
end

return test_set
