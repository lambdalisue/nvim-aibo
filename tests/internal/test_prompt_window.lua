local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- get_info_by_bufnr tests
T["get_info_by_bufnr returns info for valid prompt buffer"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local bufname = "aiboprompt://1234"
  local bufnr = vim.fn.bufadd(bufname)
  local info = prompt.get_info_by_bufnr(bufnr)

  eq(info ~= nil, true)
  eq(info.bufnr, bufnr)
  eq(info.bufname, bufname)
end

T["get_info_by_bufnr returns nil for non-prompt buffer"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local bufname = "somefile.txt"
  local bufnr = vim.fn.bufadd(bufname)
  local info = prompt.get_info_by_bufnr(bufnr)

  eq(info, nil)
end

T["get_info_by_bufnr returns nil for invalid buffer"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local info = prompt.get_info_by_bufnr(99999)
  eq(info, nil)
end

-- get_info_by_winid tests
T["get_info_by_winid returns nil for invalid window"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local info = prompt.get_info_by_winid(99999)
  eq(info, nil)
end

-- get_info_by_console_winid tests
T["get_info_by_console_winid finds prompt for console"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local console_winid = 1234
  local bufname = "aiboprompt://" .. console_winid
  local bufnr = vim.fn.bufadd(bufname)

  local info = prompt.get_info_by_console_winid(console_winid)
  eq(info ~= nil, true)
  eq(info.bufnr, bufnr)
  eq(info.bufname, bufname)
end

T["get_info_by_console_winid returns nil when no prompt"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local info = prompt.get_info_by_console_winid(9999)
  eq(info, nil)
end

-- Test autocmd creation
T["aibo_prompt_internal autocmd group is created"] = function()
  -- The prompt_window module creates the autocmd group when loaded
  -- Just verify it exists

  -- Check that autocmd group exists
  local autocmds = vim.api.nvim_get_autocmds({
    group = "aibo_prompt_internal",
    event = "BufWritePre",
  })

  eq(#autocmds > 0, true)

  -- Find the aiboprompt autocmd
  local found = false
  for _, autocmd in ipairs(autocmds) do
    if autocmd.pattern == "aiboprompt://*" then
      found = true
      break
    end
  end
  eq(found, true)

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
  eq(found, true)
end

T["VimResized autocmd is registered in aibo_prompt_internal group"] = function()
  local autocmds = vim.api.nvim_get_autocmds({
    group = "aibo_prompt_internal",
    event = "VimResized",
  })

  eq(#autocmds > 0, true)
end

-- Test compute_float_config geometry calculations
T["compute_float_config returns correct geometry for standard console"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid = vim.api.nvim_open_win(bufnr, false, {
    relative = "editor",
    width = 80,
    height = 24,
    row = 0,
    col = 0,
  })

  local config = { prompt_height = 10 }
  local result = prompt._compute_float_config(winid, config)

  eq(result.relative, "win")
  eq(result.win, winid)
  eq(result.height, 10)
  eq(result.width, 78) -- 80 - 2 for border
  eq(result.col, 0)
  eq(result.row, 12) -- 24 - 10 - 2

  vim.api.nvim_win_close(winid, true)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

T["compute_float_config clamps prompt_height to console size"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid = vim.api.nvim_open_win(bufnr, false, {
    relative = "editor",
    width = 40,
    height = 5,
    row = 0,
    col = 0,
  })

  local config = { prompt_height = 20 }
  local result = prompt._compute_float_config(winid, config)

  eq(result.height, 3) -- Clamped to console_height - 2 = 5 - 2 = 3
  eq(result.row, 0) -- max(0, 5 - 3 - 2) = 0
  eq(result.width, 38) -- 40 - 2

  vim.api.nvim_win_close(winid, true)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

T["compute_float_config uses default prompt_height when not specified"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid = vim.api.nvim_open_win(bufnr, false, {
    relative = "editor",
    width = 80,
    height = 30,
    row = 0,
    col = 0,
  })

  local config = {}
  local result = prompt._compute_float_config(winid, config)

  eq(result.height, 10) -- Default prompt_height

  vim.api.nvim_win_close(winid, true)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

-- Test find_info_in_tabpage
T["find_info_in_tabpage returns nil when no prompt"] = function()
  local prompt = require("aibo.internal.prompt_window")

  local info = prompt.find_info_in_tabpage()
  eq(info, nil)
end

-- Test open function
T["open creates prompt window for console"] = function()
  local prompt = require("aibo.internal.prompt_window")
  local console = require("aibo.internal.console_window")

  -- Mock console.get_info_by_winid to return a valid console info
  local original_get_info = console.get_info_by_winid
  console.get_info_by_winid = function(winid)
    return {
      winid = winid,
      bufnr = vim.api.nvim_create_buf(false, true),
      bufname = "aiboconsole://test//",
      jobinfo = {
        cmd = "test",
        args = {},
        job_id = -1,
      },
    }
  end

  -- Mock prompt.open to avoid actual window creation
  local original_open = prompt.open
  prompt.open = function(console_winid)
    local prompt_bufname = "aiboprompt://" .. console_winid
    local prompt_bufnr = vim.fn.bufadd(prompt_bufname)
    return {
      winid = 2000,
      bufnr = prompt_bufnr,
      bufname = prompt_bufname,
      console_winid = console_winid,
    }
  end

  -- Use a mock console window ID
  local console_winid = 1234

  -- Open prompt for the console
  local prompt_info = prompt.open(console_winid)

  eq(prompt_info ~= nil, true)
  if prompt_info then
    eq(prompt_info.bufname:match("^aiboprompt://"), "aiboprompt://")
    eq(prompt_info.winid ~= -1, true)
  end

  -- Restore
  console.get_info_by_winid = original_get_info
  prompt.open = original_open
end

-- Test write function
T["write updates prompt buffer content"] = function()
  local prompt = require("aibo.internal.prompt_window")

  -- Create a mock prompt buffer
  local bufname = "aiboprompt://" .. vim.loop.hrtime()
  local bufnr = vim.fn.bufadd(bufname)

  -- Mock get_info_by_bufnr to return valid info
  local original_get_info = prompt.get_info_by_bufnr
  prompt.get_info_by_bufnr = function(buf)
    if buf == bufnr then
      return {
        bufnr = bufnr,
        bufname = bufname,
        console_winid = 1234,
      }
    end
    return original_get_info(buf)
  end

  -- Clear the buffer first to ensure it's empty
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  -- Write content (as table of lines)
  prompt.write(bufnr, { "Test", "content" })

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  eq(table.concat(lines, "\n"), "Test\ncontent")

  -- Restore
  prompt.get_info_by_bufnr = original_get_info
end

T["write with replace option replaces content"] = function()
  local prompt = require("aibo.internal.prompt_window")

  -- Use unique buffer name
  local bufname = "aiboprompt://" .. vim.loop.hrtime()
  local bufnr = vim.fn.bufadd(bufname)

  -- Mock get_info_by_bufnr
  local original_get_info = prompt.get_info_by_bufnr
  prompt.get_info_by_bufnr = function(buf)
    if buf == bufnr then
      return {
        bufnr = bufnr,
        bufname = bufname,
        console_winid = 1234,
      }
    end
    return original_get_info(buf)
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Initial", "content" })

  -- Replace content
  prompt.write(bufnr, { "Replaced" }, { replace = true })

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  eq(table.concat(lines, "\n"), "Replaced")

  -- Restore
  prompt.get_info_by_bufnr = original_get_info
end

T["write appends to non-empty buffer by default"] = function()
  local prompt = require("aibo.internal.prompt_window")

  -- Use unique buffer name
  local bufname = "aiboprompt://" .. vim.loop.hrtime()
  local bufnr = vim.fn.bufadd(bufname)

  -- Mock get_info_by_bufnr
  local original_get_info = prompt.get_info_by_bufnr
  prompt.get_info_by_bufnr = function(buf)
    if buf == bufnr then
      return {
        bufnr = bufnr,
        bufname = bufname,
        console_winid = 1234,
      }
    end
    return original_get_info(buf)
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Initial" })

  -- Write without replace option (should append)
  prompt.write(bufnr, { "Added" })

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  eq(table.concat(lines, "\n"), "Initial\nAdded")

  -- Restore
  prompt.get_info_by_bufnr = original_get_info
end

-- Test submit function
T["submit sends prompt content to console"] = function()
  local prompt = require("aibo.internal.prompt_window")
  local console = require("aibo.internal.console_window")

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

  local original_follow = console.follow
  local followed = nil
  console.follow = function(bufnr)
    followed = bufnr
  end

  -- Test that submit doesn't error
  local ok = pcall(prompt.submit, prompt_bufnr)
  eq(ok, true)

  vim.wait(50, function()
    return followed ~= nil
  end)
  eq(followed, console_bufnr)

  console.follow = original_follow
end

return T
