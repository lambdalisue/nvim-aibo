local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

-- Store original functions
local original_select = vim.ui.select
local original_inputlist = vim.fn.inputlist

local T = helpers.new_set({
  hooks = {
    pre_case = function()
      -- Setup the AiboSend command
      require("aibo.command.aibo_send").setup()
      -- Mock vim.fn.inputlist to always select first option (avoid blocking in tests)
      vim.fn.inputlist = function(items)
        return 1
      end
    end,
    post_case = function()
      -- Restore original inputlist
      vim.fn.inputlist = original_inputlist
      -- Close leaked windows and wipe aibo buffers so a case never inherits
      -- another case's console/prompt windows. Otherwise several console
      -- windows coexist in the tabpage and AiboSend's disambiguation falls back
      -- to nvim_tabpage_list_wins order, which differs across Neovim versions
      -- (observed as a v0.10.0-only failure of "AiboSend -input option").
      local wins = vim.api.nvim_tabpage_list_wins(0)
      for i = 2, #wins do
        pcall(vim.api.nvim_win_close, wins[i], true)
      end
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(b):match("^aibo%a*://") then
          pcall(vim.api.nvim_buf_delete, b, { force = true })
        end
      end
    end,
  },
})

-- Test AiboSend command existence
T["AiboSend command exists"] = function()
  local cmd = helpers.expect.command_exists("AiboSend")
  if cmd then
    eq(cmd.range, ".") -- range returns "." string not true
    eq(cmd.nargs, "*")
  end
end

-- Test AiboSend command completion
T["AiboSend command completion"] = function()
  local completions = vim.fn.getcompletion("AiboSend ", "cmdline")
  eq(vim.tbl_contains(completions, "-input"), true)
  eq(vim.tbl_contains(completions, "-submit"), true)
  eq(vim.tbl_contains(completions, "-replace"), true)
  eq(vim.tbl_contains(completions, "-prefix="), true)
  eq(vim.tbl_contains(completions, "-suffix="), true)
end

-- Test AiboSend without console buffer
T["AiboSend without console shows error"] = function()
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
  eq(notify_called, true)
  eq(notify_msg, "No Aibo console window found in current tabpage")
end

-- Test AiboSend with single console buffer
T["AiboSend with single console"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//single")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = { "arg1" },
  }

  -- Open console in a split
  vim.cmd("vsplit")
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
  eq(prompt_buf ~= -1, true)

  -- Check that content was sent to prompt buffer
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    eq(#prompt_lines, 3)
    eq(prompt_lines[1], "line1")
    eq(prompt_lines[2], "line2")
    eq(prompt_lines[3], "line3")
  end
end

-- Test AiboSend with range
T["AiboSend with range"] = function()
  -- Since mini.test isolates tests, we need to mock the prompt module functions
  local prompt = require("aibo.internal.prompt_window")
  local aibo_send = require("aibo.command.aibo_send")

  -- Create a mock prompt buffer
  local prompt_buf = vim.api.nvim_create_buf(false, true)

  -- Mock prompt functions
  local original_find = prompt.find_info_in_tabpage
  local original_write = prompt.write

  local written_lines = nil

  prompt.find_info_in_tabpage = function()
    return {
      bufnr = prompt_buf,
      console_info = {
        winid = 1000, -- Mock window id
      },
    }
  end

  prompt.write = function(bufnr, content, options)
    if bufnr == prompt_buf then
      written_lines = content
      if options and options.replace then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
      else
        local existing = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        if #existing == 1 and existing[1] == "" then
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
        else
          vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, content)
        end
      end
      return true
    end
  end

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "line1", "line2", "line3", "line4", "line5" })

  -- Call M.call directly with range
  aibo_send.call({
    line1 = 2,
    line2 = 4,
  })

  -- Check that correct lines were written
  eq(written_lines ~= nil, true)
  if written_lines then
    eq(#written_lines, 3) -- Content is split by newlines before being passed to write
    eq(written_lines[1], "line2")
    eq(written_lines[2], "line3")
    eq(written_lines[3], "line4")
  end

  -- Also check the buffer content
  local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
  eq(#prompt_lines, 3)
  eq(prompt_lines[1], "line2")
  eq(prompt_lines[2], "line3")
  eq(prompt_lines[3], "line4")

  -- Restore
  prompt.find_info_in_tabpage = original_find
  prompt.write = original_write
end

-- Test AiboSend -input option
T["AiboSend -input option"] = function()
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
  eq(current_win, console_win)
end

-- Test AiboSend with both -input and -submit works together
T["AiboSend with both options works together"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//both")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a split
  vim.cmd("vsplit")
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
  eq(warning_shown, false)
end

-- Test AiboSend with prefix and suffix
T["AiboSend with prefix and suffix"] = function()
  local prompt = require("aibo.internal.prompt_window")
  local aibo_send = require("aibo.command.aibo_send")

  -- Create a mock prompt buffer
  local prompt_buf = vim.api.nvim_create_buf(false, true)

  -- Mock prompt functions
  local original_find = prompt.find_info_in_tabpage
  local original_write = prompt.write

  prompt.find_info_in_tabpage = function()
    return {
      bufnr = prompt_buf,
      console_info = {
        winid = 1000,
      },
    }
  end

  prompt.write = function(bufnr, content, options)
    if bufnr == prompt_buf then
      if options and options.replace then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
      else
        local existing = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        if #existing == 1 and existing[1] == "" then
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
        else
          vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, content)
        end
      end
      return true
    end
  end

  -- Create a test buffer with content
  local test_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(test_buf)
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "code" })

  -- Call M.call with prefix and suffix
  aibo_send.call({
    prefix = "Question: ",
    suffix = " Please explain.",
  })

  -- Check that content has prefix and suffix
  local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
  local content = table.concat(prompt_lines, "\n")
  eq(content, "Question: code Please explain.")

  -- Restore
  prompt.find_info_in_tabpage = original_find
  prompt.write = original_write
end

-- Test appending to non-empty prompt buffer
T["AiboSend appends to existing prompt content"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//append")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a split
  vim.cmd("vsplit")
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
    eq(#prompt_lines, 2)
    eq(prompt_lines[1], "first send")
    eq(prompt_lines[2], "second send")
  end
end

-- Test AiboSend internal completion function
T["AiboSend internal completion function"] = function()
  local aibo_send = require("aibo.command.aibo_send")
  local complete_fn = aibo_send._internal.complete

  -- Test completing options from empty arglead
  local completions = complete_fn("", "AiboSend ", 10)
  eq(vim.tbl_contains(completions, "-input"), true)
  eq(vim.tbl_contains(completions, "-submit"), true)
  eq(vim.tbl_contains(completions, "-replace"), true)
  eq(vim.tbl_contains(completions, "-prefix="), true)
  eq(vim.tbl_contains(completions, "-suffix="), true)

  -- Test completing partial options
  completions = complete_fn("-in", "AiboSend -in", 13)
  eq(vim.tbl_contains(completions, "-input"), true)
  eq(vim.tbl_contains(completions, "-submit"), false)

  -- Test completing with -pre prefix
  completions = complete_fn("-pre", "AiboSend -pre", 14)
  eq(vim.tbl_contains(completions, "-prefix="), true)
  eq(vim.tbl_contains(completions, "-input"), false)

  -- Test completing with -su prefix
  completions = complete_fn("-su", "AiboSend -su", 13)
  eq(vim.tbl_contains(completions, "-submit"), true)
  eq(vim.tbl_contains(completions, "-suffix="), true)
  eq(vim.tbl_contains(completions, "-input"), false)

  -- Test non-option arguments return empty
  completions = complete_fn("hello", "AiboSend hello", 15)
  eq(#completions, 0)

  -- Test completing with no dash prefix but empty arglead still shows options
  completions = complete_fn("", "AiboSend -input ", 17)
  eq(vim.tbl_contains(completions, "-submit"), true)
  eq(vim.tbl_contains(completions, "-replace"), true)
end

-- Test AiboSend with -replace option
T["AiboSend -replace replaces prompt content"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//replace")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a split
  vim.cmd("vsplit")
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
    eq(#prompt_lines, 2)
    eq(prompt_lines[1], "initial")
    eq(prompt_lines[2], "content")
  end

  -- Now replace with new content
  vim.api.nvim_buf_set_lines(test_buf, 0, -1, false, { "replaced", "text" })
  vim.cmd("AiboSend -replace")

  -- Check replaced content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    eq(#prompt_lines, 2)
    eq(prompt_lines[1], "replaced")
    eq(prompt_lines[2], "text")
  end
end

-- Test AiboSend -replace with range
T["AiboSend -replace with range"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//replrange")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a split
  vim.cmd("vsplit")
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
    eq(#prompt_lines, 3)
    eq(prompt_lines[1], "line1")
    eq(prompt_lines[2], "line2")
    eq(prompt_lines[3], "line3")
  end

  -- Replace with lines 4-5
  vim.cmd("4,5AiboSend -replace")

  -- Check replaced content
  if prompt_buf ~= -1 then
    local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
    eq(#prompt_lines, 2)
    eq(prompt_lines[1], "line4")
    eq(prompt_lines[2], "line5")
  end
end

-- Test AiboSend with -submit option alone
T["AiboSend -submit option"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//submit")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a split
  vim.cmd("vsplit")
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
  eq(submit_called, true)

  -- Restore
  prompt.submit = original_submit
end

-- Test M.setup creates the command
T["AiboSend setup creates command"] = function()
  local aibo_send = require("aibo.command.aibo_send")

  -- Clear any existing command
  pcall(vim.api.nvim_del_user_command, "AiboSend")

  -- Setup should create the command
  aibo_send.setup()

  -- Check command exists using helper
  local cmd = helpers.expect.command_exists("AiboSend")
  if cmd then
    eq(cmd.nargs, "*")
    eq(cmd.range, ".")
  end
end

-- Test AiboSend with empty buffer
T["AiboSend with empty buffer"] = function()
  -- Create a mock console buffer
  local console_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_buf, "aiboconsole://test//empty")
  vim.bo[console_buf].filetype = "aibo-console"
  vim.b[console_buf].aibo = {
    cmd = "test",
    args = {},
  }

  -- Open console in a split
  vim.cmd("vsplit")
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
    eq(#prompt_lines, 1)
    eq(prompt_lines[1], "")
  end
end

-- Test M.call function directly
T["M.call function with options"] = function()
  local prompt = require("aibo.internal.prompt_window")
  local aibo_send = require("aibo.command.aibo_send")

  -- Create a mock prompt buffer
  local prompt_buf = vim.api.nvim_create_buf(false, true)

  -- Mock prompt functions
  local original_find = prompt.find_info_in_tabpage
  local original_write = prompt.write

  prompt.find_info_in_tabpage = function()
    return {
      bufnr = prompt_buf,
      console_info = {
        winid = 1000,
      },
    }
  end

  prompt.write = function(bufnr, content, options)
    if bufnr == prompt_buf then
      if options and options.replace then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
      else
        local existing = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        if #existing == 1 and existing[1] == "" then
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
        else
          vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, content)
        end
      end
      return true
    end
  end

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
  local prompt_lines = vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false)
  local content = table.concat(prompt_lines, "\n")
  eq(content, ">>> line2\nline3 <<<")

  -- Restore
  prompt.find_info_in_tabpage = original_find
  prompt.write = original_write
end

return T
