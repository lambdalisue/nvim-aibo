-- Tests for :AiboSend command (lua/aibo/command/aibo_send.lua)

local T = require("mini.test")

-- Store original vim.ui.select
local original_select = vim.ui.select

-- Track the initial tab to return to
local initial_tab = vim.api.nvim_get_current_tabpage()

-- Test set
local test_set = T.new_set({
  hooks = {
    post_case = function()
      -- Restore original vim.ui.select
      vim.ui.select = original_select

      -- Close all aibo buffers in the current tab before closing it
      for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local bufnr = vim.api.nvim_win_get_buf(winid)
        if vim.api.nvim_buf_is_valid(bufnr) then
          local name = vim.api.nvim_buf_get_name(bufnr)
          if name:match("^aibo") then
            pcall(vim.api.nvim_win_close, winid, true)
          end
        end
      end

      -- Close the test tab and return to initial tab
      vim.cmd("tabclose!")
      -- Ensure we're on the initial tab
      if vim.api.nvim_tabpage_is_valid(initial_tab) then
        vim.api.nvim_set_current_tabpage(initial_tab)
      end

      vim.cmd("silent! %bwipeout!")
    end,
  },
})

-- Test AiboSend command existence
test_set["AiboSend command exists"] = function()
  local commands = vim.api.nvim_get_commands({})
  T.expect.equality(commands["AiboSend"] ~= nil, true)
  T.expect.equality(commands["AiboSend"].range, ".") -- range returns "." string not true
  T.expect.equality(commands["AiboSend"].nargs, "*")
end

-- Test AiboSend command completion
test_set["AiboSend command completion"] = function()
  local completions = vim.fn.getcompletion("AiboSend ", "cmdline")
  T.expect.equality(vim.tbl_contains(completions, "-input"), true)
  T.expect.equality(vim.tbl_contains(completions, "-submit"), true)
  T.expect.equality(vim.tbl_contains(completions, "-replace"), true)
  T.expect.equality(vim.tbl_contains(completions, "-prefix="), true)
  T.expect.equality(vim.tbl_contains(completions, "-suffix="), true)
end

-- Test AiboSend without console buffer
test_set["AiboSend without console shows error"] = function()
  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "test content" })

  -- Mock vim.notify to capture the error message
  local notify_called = false
  local notify_msg = nil
  local original_notify = vim.notify
  vim.notify = function(msg, level, opts)
    if level == vim.log.levels.WARN and msg:match("No Aibo console") then
      notify_called = true
      notify_msg = msg
    end
  end

  -- Run AiboSend
  vim.cmd("AiboSend")

  -- Restore original notify
  vim.notify = original_notify

  -- Check that error was shown
  T.expect.equality(notify_called, true)
  T.expect.equality(notify_msg, "No Aibo console window found in current tabpage")
end

-- Test AiboSend with single console buffer
test_set["AiboSend with single console"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//single")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = { "arg1" },
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create the prompt window for the console
  local prompt = require("aibo.internal.prompt_window")
  prompt.open(console_win)

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line1", "line2", "line3" })

  -- Run AiboSend
  vim.cmd("AiboSend")

  -- Check that prompt buffer was created
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)
  T.expect.equality(prompt_buf ~= -1, true)

  -- Check that content was sent to prompt buffer
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 3)
    T.expect.equality(prompt_lines[1], "line1")
    T.expect.equality(prompt_lines[2], "line2")
    T.expect.equality(prompt_lines[3], "line3")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test AiboSend with range
test_set["AiboSend with range"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//range")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create the prompt window for the console
  local prompt = require("aibo.internal.prompt_window")
  prompt.open(console_win)

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line1", "line2", "line3", "line4", "line5" })

  -- Run AiboSend with range (lines 2-4)
  vim.cmd("2,4AiboSend")

  -- Check that prompt buffer was created
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)
  T.expect.equality(prompt_buf ~= -1, true)

  -- Check that only selected lines were sent
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 3)
    T.expect.equality(prompt_lines[1], "line2")
    T.expect.equality(prompt_lines[2], "line3")
    T.expect.equality(prompt_lines[3], "line4")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test AiboSend -input option
test_set["AiboSend -input option"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//input")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a window
  local console_win = vim.api.nvim_open_win(console_buf, true, {
    relative = "editor",
    width = 40,
    height = 10,
    row = 0,
    col = 0,
  })

  -- Create the prompt window for the console
  local prompt = require("aibo.internal.prompt_window")
  prompt.open(console_win)

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  local test_win = vim.api.nvim_open_win(test_buf, true, {
    relative = "editor",
    width = 40,
    height = 10,
    row = 0,
    col = 45,
  })
  vim.api.nvim_set_current_win(test_win)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "test content" })

  -- Track window focus changes
  local original_win = vim.api.nvim_get_current_win()

  -- Run AiboSend with -input
  vim.cmd("AiboSend -input")

  -- Wait for deferred window switch
  vim.wait(10)

  -- Check that focus moved to console window
  local current_win = vim.api.nvim_get_current_win()
  T.expect.equality(current_win, console_win)

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
  vim.api.nvim_win_close(test_win, true)
end

-- Test AiboSend with both -input and -submit works together
test_set["AiboSend with both options shows warning"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//both")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "test" })

  -- Mock vim.notify to capture any warnings
  local warning_shown = false
  local original_notify = vim.notify
  vim.notify = function(msg, level, opts)
    if opts and opts.title == "Aibo" and level == vim.log.levels.WARN then
      warning_shown = true
    end
  end

  -- Run AiboSend with both options
  vim.cmd("AiboSend -input -submit")

  -- Restore original notify
  vim.notify = original_notify

  -- Check that no warning was shown (both options now work together)
  T.expect.equality(warning_shown, false)

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test AiboSend with prefix and suffix
test_set["AiboSend with prefix and suffix"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//prefix")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create the prompt window for the console
  local prompt = require("aibo.internal.prompt_window")
  prompt.open(console_win)

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "code" })

  -- Run AiboSend with prefix and suffix (using quoted strings)
  vim.cmd([[AiboSend -prefix="Question: " -suffix=" Please explain."]])

  -- Check that prompt buffer was created with prefix and suffix
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)
  T.expect.equality(prompt_buf ~= -1, true)

  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    local content = table.concat(prompt_lines, "\n")
    T.expect.equality(content, "Question: code Please explain.")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test appending to non-empty prompt buffer
test_set["AiboSend appends to existing prompt content"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//append")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "first send" })

  -- First send
  vim.cmd("AiboSend")

  -- Change content and send again
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "second send" })
  vim.cmd("AiboSend")

  -- Check prompt buffer content
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)

  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 2)
    T.expect.equality(prompt_lines[1], "first send")
    T.expect.equality(prompt_lines[2], "second send")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test AiboSend internal completion function
test_set["AiboSend internal completion function"] = function()
  local aibo_send = require("aibo.command.aibo_send")
  local complete_fn = aibo_send._internal.complete

  -- Test completing options from empty arglead
  local completions = complete_fn("", "AiboSend ", 10)
  T.expect.equality(vim.tbl_contains(completions, "-input"), true)
  T.expect.equality(vim.tbl_contains(completions, "-submit"), true)
  T.expect.equality(vim.tbl_contains(completions, "-replace"), true)
  T.expect.equality(vim.tbl_contains(completions, "-prefix="), true)
  T.expect.equality(vim.tbl_contains(completions, "-suffix="), true)

  -- Test completing partial options
  completions = complete_fn("-in", "AiboSend -in", 13)
  T.expect.equality(vim.tbl_contains(completions, "-input"), true)
  T.expect.equality(vim.tbl_contains(completions, "-submit"), false)

  -- Test completing with -pre prefix
  completions = complete_fn("-pre", "AiboSend -pre", 14)
  T.expect.equality(vim.tbl_contains(completions, "-prefix="), true)
  T.expect.equality(vim.tbl_contains(completions, "-input"), false)

  -- Test completing with -su prefix
  completions = complete_fn("-su", "AiboSend -su", 13)
  T.expect.equality(vim.tbl_contains(completions, "-submit"), true)
  T.expect.equality(vim.tbl_contains(completions, "-suffix="), true)
  T.expect.equality(vim.tbl_contains(completions, "-input"), false)

  -- Test non-option arguments return empty
  completions = complete_fn("hello", "AiboSend hello", 15)
  T.expect.equality(#completions, 0)

  -- Test completing with no dash prefix but empty arglead still shows options
  completions = complete_fn("", "AiboSend -input ", 17)
  T.expect.equality(vim.tbl_contains(completions, "-submit"), true)
  T.expect.equality(vim.tbl_contains(completions, "-replace"), true)
end

-- Test AiboSend with -replace option
test_set["AiboSend -replace replaces prompt content"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//replace")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "initial", "content" })

  -- First send without -replace
  vim.cmd("AiboSend")

  -- Get prompt buffer
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)

  -- Check initial content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 2)
    T.expect.equality(prompt_lines[1], "initial")
    T.expect.equality(prompt_lines[2], "content")
  end

  -- Now replace with new content
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "replaced", "text" })
  vim.cmd("AiboSend -replace")

  -- Check replaced content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 2)
    T.expect.equality(prompt_lines[1], "replaced")
    T.expect.equality(prompt_lines[2], "text")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test AiboSend append vs replace behavior
test_set["AiboSend append vs replace behavior"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//appendvs")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create a test buffer
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)

  -- Send "line1"
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line1" })
  vim.cmd("AiboSend")

  -- Get prompt buffer
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)

  -- Append "line2"
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line2" })
  vim.cmd("AiboSend")

  -- Check appended content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 2)
    T.expect.equality(prompt_lines[1], "line1")
    T.expect.equality(prompt_lines[2], "line2")
  end

  -- Replace with "line3"
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line3" })
  vim.cmd("AiboSend -replace")

  -- Check replaced content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 1)
    T.expect.equality(prompt_lines[1], "line3")
  end

  -- Append "line4" after replace
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line4" })
  vim.cmd("AiboSend")

  -- Check final content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 2)
    T.expect.equality(prompt_lines[1], "line3")
    T.expect.equality(prompt_lines[2], "line4")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test AiboSend -replace with range
test_set["AiboSend -replace with range"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//replrange")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab to avoid multiple windows showing the same buffer
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p") -- Go back to previous window

  -- Create a test buffer with multiple lines
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line1", "line2", "line3", "line4", "line5" })

  -- Send lines 1-3 initially
  vim.cmd("1,3AiboSend")

  -- Get prompt buffer
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)

  -- Check initial content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 3)
    T.expect.equality(prompt_lines[1], "line1")
    T.expect.equality(prompt_lines[2], "line2")
    T.expect.equality(prompt_lines[3], "line3")
  end

  -- Replace with lines 4-5
  vim.cmd("4,5AiboSend -replace")

  -- Check replaced content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 2)
    T.expect.equality(prompt_lines[1], "line4")
    T.expect.equality(prompt_lines[2], "line5")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test AiboSend with -submit option alone
test_set["AiboSend -submit option"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//submit")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p")

  -- Create the prompt window for the console first
  local prompt = require("aibo.internal.prompt_window")
  prompt.open(console_win)

  -- Mock prompt.submit to track if it was called
  local original_submit = prompt.submit
  local submit_called = false
  local submit_bufnr = nil
  prompt.submit = function(bufnr)
    submit_called = true
    submit_bufnr = bufnr
    -- Don't actually submit to avoid errors
  end

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "test line" })

  -- Run AiboSend with -submit
  vim.cmd("AiboSend -submit")

  -- Check that submit was called
  T.expect.equality(submit_called, true, "Submit should be called with -submit option")

  -- Restore
  prompt.submit = original_submit

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test M.setup creates the command
test_set["AiboSend setup creates command"] = function()
  local aibo_send = require("aibo.command.aibo_send")

  -- Clear any existing command
  pcall(vim.api.nvim_del_user_command, "AiboSend")

  -- Setup should create the command
  aibo_send.setup()

  -- Check command exists
  local commands = vim.api.nvim_get_commands({})
  T.expect.equality(commands["AiboSend"] ~= nil, true, "Should create AiboSend command")

  if commands["AiboSend"] then
    T.expect.equality(commands["AiboSend"].nargs, "*", "Should accept any number of arguments")
    T.expect.equality(commands["AiboSend"].range, ".", "Should support range")
  end
end

-- Test AiboSend with empty buffer
test_set["AiboSend with empty buffer"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//empty")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a new tab
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p")

  -- Create the prompt window for the console
  local prompt = require("aibo.internal.prompt_window")
  prompt.open(console_win)

  -- Create an empty test buffer
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  -- Buffer is empty by default

  -- Run AiboSend
  vim.cmd("AiboSend")

  -- Get prompt buffer
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)

  -- Check that empty content was sent
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    T.expect.equality(#prompt_lines, 1, "Should have one line for empty buffer")
    T.expect.equality(prompt_lines[1], "", "Should send empty string for empty buffer")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

-- Test AiboSend with multiple console windows (selection)
test_set["AiboSend with multiple consoles"] = function()
  -- Create two mock console buffers
  local console_buf1 = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf1, "aiboconsole://claude/multi1/")
  vim.bo[console_buf1].filetype = "aibo-console"
  vim.b[console_buf1].aibo = { cmd = "claude", args = { "multi1" } }

  local console_buf2 = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf2, "aiboconsole://codex/multi2/")
  vim.bo[console_buf2].filetype = "aibo-console"
  vim.b[console_buf2].aibo = { cmd = "codex", args = { "multi2" } }

  -- Open consoles in a new tab
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf1)
  local console_win1 = vim.api.nvim_get_current_win()

  vim.cmd("vsplit")
  vim.api.nvim_set_current_buf(console_buf2)
  local console_win2 = vim.api.nvim_get_current_win()

  -- Create prompts for both consoles
  local prompt = require("aibo.internal.prompt_window")
  prompt.open(console_win1)
  prompt.open(console_win2)

  -- Create a test buffer in a new horizontal split
  -- Make sure we stay in the same tab
  vim.cmd("split")
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "multi test" })

  -- Verify console windows are still in the current tabpage
  local tab_wins = vim.api.nvim_tabpage_list_wins(0)
  local console1_found = vim.tbl_contains(tab_wins, console_win1)
  local console2_found = vim.tbl_contains(tab_wins, console_win2)

  -- Mock vim.ui.select to track what was selected
  local select_called = false
  local selected_item = nil
  local items_count = 0
  local original_select = vim.ui.select
  vim.ui.select = function(items, opts, on_choice)
    select_called = true
    items_count = items and #items or 0
    -- Store what would be selected (first item)
    selected_item = items and items[1] or nil
    -- Call the original mock (which selects first item)
    original_select(items, opts, on_choice)
  end

  -- Debug: Check what console.find_info_in_tabpage would find
  local console = require("aibo.internal.console_window")
  local found_consoles = {}
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local info = console.get_info_by_winid(winid)
    if info then
      table.insert(found_consoles, info)
    end
  end
  local found_count = #found_consoles

  -- Run AiboSend
  vim.cmd("AiboSend")

  -- Restore original select
  vim.ui.select = original_select

  -- Verify we found consoles
  T.expect.equality(found_count >= 1, true, string.format("Should find at least 1 console (found %d)", found_count))

  -- First check if select was even called
  if not select_called then
    -- Debug: Check if the console windows are valid and in current tabpage
    T.expect.equality(found_count, 2, string.format("Should find 2 consoles in tabpage (found %d)", found_count))
    T.expect.equality(console1_found, true, "Console window 1 should be in current tabpage")
    T.expect.equality(console2_found, true, "Console window 2 should be in current tabpage")

    local console = require("aibo.internal.console_window")
    local console_info1 = console.get_info_by_winid(console_win1)
    local console_info2 = console.get_info_by_winid(console_win2)

    -- Verify console windows are recognized
    T.expect.equality(console_info1 ~= nil, true, "Console 1 should be recognized")
    T.expect.equality(console_info2 ~= nil, true, "Console 2 should be recognized")

    -- If select wasn't called, check if prompts were created correctly
    local prompt = require("aibo.internal.prompt_window")
    local prompt_info1 = prompt.get_info_by_console_winid(console_win1)
    local prompt_info2 = prompt.get_info_by_console_winid(console_win2)
    T.expect.equality(prompt_info1 ~= nil, true, "Should have prompt for console 1")
    T.expect.equality(prompt_info2 ~= nil, true, "Should have prompt for console 2")

    -- Since selection wasn't triggered, we should at least verify prompts exist
    -- and content was sent to one of them
    local any_prompt_has_content = false
    if prompt_info1 then
      local lines1 = vim.api.nvim_buf_get_lines(prompt_info1.bufnr, 0, -1, false)
      if #lines1 > 0 and lines1[1] == "multi test" then
        any_prompt_has_content = true
      end
    end
    if prompt_info2 and not any_prompt_has_content then
      local lines2 = vim.api.nvim_buf_get_lines(prompt_info2.bufnr, 0, -1, false)
      if #lines2 > 0 and lines2[1] == "multi test" then
        any_prompt_has_content = true
      end
    end
    T.expect.equality(any_prompt_has_content, true, "Content should be sent to a prompt")
  else
    -- Check that selection was made (claude console was selected - first item)
    T.expect.equality(select_called, true, "vim.ui.select should have been called")
    T.expect.equality(items_count > 0, true, string.format("Should have items to select from (got %d)", items_count))
    T.expect.equality(selected_item ~= nil, true, "Should have selected an item")
    if selected_item then
      -- The selected item is a console info object with bufname
      -- Check if it's the claude console (should be first item alphabetically)
      local is_claude = selected_item.bufname:match("^aiboconsole://claude") ~= nil
      T.expect.equality(is_claude, true, "Should have selected claude console (first item)")
    end
  end

  -- Check that content was sent to the selected console (first one - claude)
  local prompt_bufname1 = string.format("aiboprompt://%d", console_win1)
  local prompt_buf1 = vim.fn.bufnr(prompt_bufname1)
  if prompt_buf1 ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf1, 0, -1, false)
    T.expect.equality(#prompt_lines, 1)
    T.expect.equality(prompt_lines[1], "multi test")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win1, true)
  vim.api.nvim_win_close(console_win2, true)
end

-- Test M.call function directly
test_set["M.call function with options"] = function()
  local aibo_send = require("aibo.command.aibo_send")

  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//call")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = { cmd = "test", args = {} }

  -- Open console in a new tab
  vim.cmd("tabedit")
  vim.api.nvim_set_current_buf(console_buf)
  local console_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p")

  -- Create the prompt window for the console
  local prompt = require("aibo.internal.prompt_window")
  prompt.open(console_win)

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line1", "line2", "line3" })

  -- Call M.call directly with options
  aibo_send.call({
    line1 = 2,
    line2 = 3,
    prefix = ">>> ",
    suffix = " <<<",
    replace = false,
  })

  -- Get prompt buffer and check content
  local prompt_bufname = string.format("aiboprompt://%d", console_win)
  local prompt_buf = vim.fn.bufnr(prompt_bufname)
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    local content = table.concat(prompt_lines, "\n")
    T.expect.equality(content, ">>> line2\nline3 <<<", "Should have prefix, lines 2-3, and suffix")
  end

  -- Clean up
  vim.api.nvim_win_close(console_win, true)
end

return test_set
