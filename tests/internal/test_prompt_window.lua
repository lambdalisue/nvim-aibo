-- Tests for prompt_window module (lua/aibo/internal/prompt_window.lua)

local T = require("mini.test")

-- Test set
-- Load modules first to ensure autocmd groups exist
local _console = require("aibo.internal.console_window")
local _prompt = require("aibo.internal.prompt_window")

local test_set = T.new_set({
  hooks = {
    post_case = function()
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

-- get_info_by_bufnr tests
test_set["get_info_by_bufnr returns info for valid prompt buffer"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local bufname = "aiboprompt://1234"
  local bufnr = vim.fn.bufadd(bufname)
  local info = prompt.get_info_by_bufnr(bufnr)

  T.expect.equality(info ~= nil, true, "Should parse prompt buffer name")
  T.expect.equality(info.bufnr, bufnr, "Should have correct bufnr")
  T.expect.equality(info.bufname, bufname, "Should have correct bufname")
end

test_set["get_info_by_bufnr returns nil for non-prompt buffer"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local bufname = "somefile.txt"
  local bufnr = vim.fn.bufadd(bufname)
  local info = prompt.get_info_by_bufnr(bufnr)

  T.expect.equality(info, nil, "Should return nil for non-prompt buffer")
end

test_set["get_info_by_bufnr returns nil for invalid buffer"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local info = prompt.get_info_by_bufnr(99999)
  T.expect.equality(info, nil, "Should return nil for invalid buffer")
end

-- get_info_by_winid tests
test_set["get_info_by_winid returns nil for invalid window"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local info = prompt.get_info_by_winid(99999)
  T.expect.equality(info, nil, "Should return nil for invalid window")
end

-- get_info_by_console_winid tests
test_set["get_info_by_console_winid finds prompt for console"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local console_winid = 1234
  local bufname = "aiboprompt://" .. console_winid
  local bufnr = vim.fn.bufadd(bufname)

  local info = prompt.get_info_by_console_winid(console_winid)
  T.expect.equality(info ~= nil, true, "Should find prompt for console")
  T.expect.equality(info.bufnr, bufnr, "Should have correct bufnr")
  T.expect.equality(info.bufname, bufname, "Should have correct bufname")
end

test_set["get_info_by_console_winid returns nil when no prompt"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local info = prompt.get_info_by_console_winid(9999)
  T.expect.equality(info, nil, "Should return nil when no prompt exists")
end

-- Test autocmd creation
test_set["aibo_prompt_internal autocmd group is created"] = function()
  -- The prompt_window module creates the autocmd group when loaded
  -- It's already loaded at the top of this file, so we just verify it exists

  -- Check that autocmd group exists
  local autocmds = vim.api.nvim_get_autocmds({
    group = "aibo_prompt_internal",
    event = "BufWritePre",
  })

  T.expect.equality(#autocmds > 0, true, "Should have BufWritePre autocmd")

  -- Find the aiboprompt autocmd
  local found = false
  for _, autocmd in ipairs(autocmds) do
    if autocmd.pattern == "aiboprompt://*" then
      found = true
      break
    end
  end
  T.expect.equality(found, true, "Should have aiboprompt://* pattern")

  -- Also check BufWriteCmd
  autocmds = vim.api.nvim_get_autocmds({
    group = "aibo_prompt_internal",
    event = "BufWriteCmd",
  })

  found = false
  for _, autocmd in ipairs(autocmds) do
    if autocmd.pattern == "aiboprompt://*" then
      found = true
      break
    end
  end
  T.expect.equality(found, true, "Should have BufWriteCmd for aiboprompt://*")
end

-- Test find_info_in_tabpage
test_set["find_info_in_tabpage returns nil when no prompt"] = function()
  local prompt = require("aibo.internal.prompt_window")

  -- Ensure no prompt buffers exist in windows
  vim.cmd("silent! %bwipeout!")

  local info = prompt.find_info_in_tabpage()
  T.expect.equality(info, nil, "Should return nil when no prompt in tabpage")
end

-- Test open function
test_set["open creates prompt window for console"] = function()
  local prompt = require("aibo.internal.prompt_window")

  -- Create a unique console window
  local console_buf = vim.api.nvim_create_buf(false, true)
  local unique_name = "aiboconsole://test_" .. os.time() .. "/"
  vim.api.nvim_buf_set_name(console_buf, unique_name)
  vim.cmd("split")
  vim.api.nvim_win_set_buf(0, console_buf)
  local console_winid = vim.api.nvim_get_current_win()

  -- Open prompt for the console
  local prompt_info = prompt.open(console_winid)

  T.expect.equality(prompt_info ~= nil, true, "Should create prompt window")
  if prompt_info then
    T.expect.equality(prompt_info.bufname:match("^aiboprompt://"), "aiboprompt://", "Should have prompt buffer name")
    T.expect.equality(prompt_info.winid ~= -1, true, "Should have valid window ID")
  end
end

-- Test write function
test_set["write updates prompt buffer content"] = function()
  local prompt = require("aibo.internal.prompt_window")

  -- Use a unique buffer name to avoid conflicts
  local bufname = "aiboprompt://" .. vim.loop.hrtime()
  local bufnr = vim.fn.bufadd(bufname)

  -- Clear the buffer first to ensure it's empty
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  -- Write content (as table of lines)
  prompt.write(bufnr, { "Test", "content" })

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  T.expect.equality(table.concat(lines, "\n"), "Test\ncontent", "Should have correct content")
end

test_set["write with replace option replaces content"] = function()
  local prompt = require("aibo.internal.prompt_window")

  -- Use unique buffer name
  local bufname = "aiboprompt://" .. vim.loop.hrtime()
  local bufnr = vim.fn.bufadd(bufname)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Initial", "content" })

  -- Replace content
  prompt.write(bufnr, { "Replaced" }, { replace = true })

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  T.expect.equality(table.concat(lines, "\n"), "Replaced", "Should replace content")
end

test_set["write appends to non-empty buffer by default"] = function()
  local prompt = require("aibo.internal.prompt_window")

  -- Use unique buffer name
  local bufname = "aiboprompt://" .. vim.loop.hrtime()
  local bufnr = vim.fn.bufadd(bufname)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Initial" })

  -- Write without replace option (should append)
  prompt.write(bufnr, { "Added" })

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  T.expect.equality(table.concat(lines, "\n"), "Initial\nAdded", "Should append content")
end

-- Test submit function
test_set["submit sends prompt content to console"] = function()
  local prompt = require("aibo.internal.prompt_window")

  -- Create a console buffer with terminal
  local console_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(console_bufnr, "aiboconsole://test claude")
  local chan = vim.api.nvim_open_term(console_bufnr, {})
  vim.b[console_bufnr].terminal_job_id = chan

  -- Create and setup prompt buffer
  local console_winid = 1234
  local prompt_bufname = "aiboprompt://" .. console_winid
  local prompt_bufnr = vim.fn.bufadd(prompt_bufname)
  vim.b[prompt_bufnr].aibo_console_bufnr = console_bufnr
  vim.api.nvim_buf_set_lines(prompt_bufnr, 0, -1, false, { "Test submission" })

  -- Test that submit doesn't error
  local ok = pcall(prompt.submit, prompt_bufnr)
  T.expect.equality(ok, true, "Should submit without error")
end

return test_set
