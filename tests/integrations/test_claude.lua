-- Tests for Claude integration (lua/aibo/integration/claude.lua)

local mock = require("tests.mock")
local T = require("mini.test")

-- Test set
local test_set = T.new_set({
  hooks = {
    post_case = function()
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

-- Test Claude command availability
test_set["Claude is_available"] = function()
  local claude = require("aibo.integration.claude")

  -- Mock executable
  local restore = mock.mock_executable({
    claude = true,
  })

  T.expect.equality(claude.is_available(), true)

  -- Test when not available
  vim.fn.executable = function()
    return 0
  end
  T.expect.equality(claude.is_available(), false)

  restore()
end

-- Test Claude command completions
test_set["Claude argument completions"] = function()
  local claude = require("aibo.integration.claude")

  -- Test completing arguments at the start
  local completions = claude.get_command_completions("", "claude ", 7)
  T.expect.equality(vim.tbl_contains(completions, "--continue"), true)
  T.expect.equality(vim.tbl_contains(completions, "--model"), true)
  T.expect.equality(vim.tbl_contains(completions, "--permission-mode"), true)

  -- Test completing partial argument
  completions = claude.get_command_completions("--con", "claude --con", 12)
  T.expect.equality(vim.tbl_contains(completions, "--continue"), true)
  T.expect.equality(vim.tbl_contains(completions, "--model"), false)

  -- Test completing short form
  completions = claude.get_command_completions("-c", "claude -c", 9)
  T.expect.equality(vim.tbl_contains(completions, "-c"), true)
  T.expect.equality(vim.tbl_contains(completions, "--continue"), false)
end

-- Test Claude model completions
test_set["Claude model value completions"] = function()
  local claude = require("aibo.integration.claude")

  -- Test completing model values
  local completions = claude.get_command_completions("", "claude --model ", 15)
  T.expect.equality(vim.tbl_contains(completions, "sonnet"), true)
  T.expect.equality(vim.tbl_contains(completions, "opus"), true)
  T.expect.equality(vim.tbl_contains(completions, "haiku"), true)
  T.expect.equality(vim.tbl_contains(completions, "claude-3-5-sonnet-latest"), true)

  -- Test partial model completion
  completions = claude.get_command_completions("son", "claude --model son", 18)
  T.expect.equality(vim.tbl_contains(completions, "sonnet"), true)
  T.expect.equality(vim.tbl_contains(completions, "opus"), false)

  -- Test with short form
  completions = claude.get_command_completions("", "claude -m ", 10)
  T.expect.equality(#completions == 0, true) -- Short form not recognized for --model
end

-- Test Claude check_health function
test_set["Claude check_health"] = function()
  local claude = require("aibo.integration.claude")

  -- Mock reporter
  local reports = {}
  local reporter = {
    start = function(msg)
      table.insert(reports, { type = "start", msg = msg })
    end,
    ok = function(msg)
      table.insert(reports, { type = "ok", msg = msg })
    end,
    warn = function(msg)
      table.insert(reports, { type = "warn", msg = msg })
    end,
    info = function(msg)
      table.insert(reports, { type = "info", msg = msg })
    end,
  }

  -- Mock executable
  local restore = mock.mock_executable({
    claude = true,
  })

  -- Run health check
  claude.check_health(reporter)

  -- Check that appropriate messages were reported
  T.expect.equality(reports[1].type, "start")
  T.expect.equality(reports[1].msg:find("Claude") ~= nil, true)

  -- Should report that claude is found
  local has_ok_report = false
  for _, report in ipairs(reports) do
    if report.type == "ok" and report.msg:find("claude") then
      has_ok_report = true
      break
    end
  end
  T.expect.equality(has_ok_report, true, "Should report claude is available")

  restore()
end

-- Test Claude permission mode completions
test_set["Claude permission-mode value completions"] = function()
  local claude = require("aibo.integration.claude")

  -- Test completing permission modes
  local completions = claude.get_command_completions("", "claude --permission-mode ", 26)
  T.expect.equality(vim.tbl_contains(completions, "default"), true)
  T.expect.equality(vim.tbl_contains(completions, "acceptEdits"), true)
  T.expect.equality(vim.tbl_contains(completions, "bypassPermissions"), true)
  T.expect.equality(vim.tbl_contains(completions, "plan"), true)

  -- Test partial completion
  completions = claude.get_command_completions("acc", "claude --permission-mode acc", 29)
  T.expect.equality(vim.tbl_contains(completions, "acceptEdits"), true)
  T.expect.equality(vim.tbl_contains(completions, "default"), false)
end

-- Test Claude file/directory completions
test_set["Claude file and directory completions"] = function()
  local claude = require("aibo.integration.claude")

  -- Mock getcompletion for directories
  local original_getcompletion = vim.fn.getcompletion
  vim.fn.getcompletion = function(arg, type)
    if type == "dir" then
      return { "/home/user/", "/tmp/", "/var/" }
    elseif type == "file" then
      return { "config.json", "settings.json" }
    end
    return {}
  end

  -- Test --add-dir completion
  local completions = claude.get_command_completions("", "claude --add-dir ", 17)
  T.expect.equality(vim.tbl_contains(completions, "/home/user/"), true)
  T.expect.equality(vim.tbl_contains(completions, "/tmp/"), true)

  -- Test --settings completion
  completions = claude.get_command_completions("", "claude --settings ", 18)
  T.expect.equality(vim.tbl_contains(completions, "config.json"), true)
  T.expect.equality(vim.tbl_contains(completions, "settings.json"), true)

  vim.fn.getcompletion = original_getcompletion
end

return test_set
