-- Tests for OpenAI Codex integration (lua/aibo/integration/codex.lua)

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

-- Test Codex is_available
test_set["Codex is_available"] = function()
  local codex = require("aibo.integration.codex")

  -- Mock executable
  local restore = mock.mock_executable({
    codex = true,
  })

  T.expect.equality(codex.is_available(), true, "Should be available when codex exists")

  -- Test when not available
  vim.fn.executable = function()
    return 0
  end
  T.expect.equality(codex.is_available(), false, "Should not be available when codex missing")

  restore()
end

-- Test Codex argument completions
test_set["Codex argument completions"] = function()
  local codex = require("aibo.integration.codex")

  -- Test completing arguments at the start
  local completions = codex.get_command_completions("", "codex ", 6)
  T.expect.equality(vim.tbl_contains(completions, "--model"), true)
  T.expect.equality(vim.tbl_contains(completions, "--ask-for-approval"), true)
  T.expect.equality(vim.tbl_contains(completions, "--cd"), true)
  T.expect.equality(vim.tbl_contains(completions, "--full-auto"), true)
  T.expect.equality(vim.tbl_contains(completions, "--image"), true)
  T.expect.equality(vim.tbl_contains(completions, "resume"), true)

  -- Test things that should NOT be in the new implementation
  T.expect.equality(vim.tbl_contains(completions, "--config"), false)
  T.expect.equality(vim.tbl_contains(completions, "--profile"), false)
  T.expect.equality(vim.tbl_contains(completions, "--sandbox"), false)
  T.expect.equality(vim.tbl_contains(completions, "--oss"), false)
  T.expect.equality(vim.tbl_contains(completions, "exec"), false) -- Non-interactive

  -- Test completing partial argument
  completions = codex.get_command_completions("--mod", "codex --mod", 11)
  T.expect.equality(vim.tbl_contains(completions, "--model"), true)
  T.expect.equality(vim.tbl_contains(completions, "--ask-for-approval"), false)

  -- Test completing short forms
  completions = codex.get_command_completions("-m", "codex -m", 8)
  T.expect.equality(vim.tbl_contains(completions, "-m"), true)
  T.expect.equality(vim.tbl_contains(completions, "--model"), false)

  completions = codex.get_command_completions("-a", "codex -a", 8)
  T.expect.equality(vim.tbl_contains(completions, "-a"), true)

  completions = codex.get_command_completions("-C", "codex -C", 8)
  T.expect.equality(vim.tbl_contains(completions, "-C"), true)

  completions = codex.get_command_completions("-i", "codex -i", 8)
  T.expect.equality(vim.tbl_contains(completions, "-i"), true)
end

-- Test Codex subcommand completions
test_set["Codex subcommand completions"] = function()
  local codex = require("aibo.integration.codex")

  -- Test completing "resume"
  local completions = codex.get_command_completions("res", "codex res", 9)
  T.expect.equality(vim.tbl_contains(completions, "resume"), true)

  -- Test that non-interactive subcommands are NOT there
  T.expect.equality(vim.tbl_contains(completions, "exec"), false)
  T.expect.equality(vim.tbl_contains(completions, "completion"), false)

  -- Test completing full "resume" - when already typed, should offer other options or be empty
  completions = codex.get_command_completions("resume", "codex resume", 12)
  -- When "resume" is fully typed, it's recognized as a complete subcommand
  -- The completion list might be empty or contain other valid options
  T.expect.equality(type(completions), "table")

  -- Test with space after resume - should show --last option
  completions = codex.get_command_completions("", "codex resume ", 13)
  T.expect.equality(vim.tbl_contains(completions, "--last"), true)
  -- Should also show regular arguments
  T.expect.equality(vim.tbl_contains(completions, "--model"), true)

  -- Test completing --last after resume
  completions = codex.get_command_completions("--l", "codex resume --l", 17)
  T.expect.equality(vim.tbl_contains(completions, "--last"), true)
end

-- Test Codex model completions
test_set["Codex model value completions"] = function()
  local codex = require("aibo.integration.codex")

  -- Test completing model values - OpenAI Codex doesn't have predefined model list
  local completions = codex.get_command_completions("", "codex --model ", 14)
  T.expect.equality(#completions, 0) -- No predefined values

  -- Test with short form
  completions = codex.get_command_completions("", "codex -m ", 9)
  T.expect.equality(#completions, 0) -- No predefined values
end

-- Test Codex working directory completions
test_set["Codex cd directory completions"] = function()
  local codex = require("aibo.integration.codex")

  -- Mock getcompletion for directories
  local original_getcompletion = vim.fn.getcompletion
  vim.fn.getcompletion = function(arg, type)
    if type == "dir" then
      return { "/home/user/projects/", "/home/user/documents/", "/tmp/" }
    end
    return {}
  end

  -- Test --cd completion
  local completions = codex.get_command_completions("", "codex --cd ", 11)
  T.expect.equality(vim.tbl_contains(completions, "/home/user/projects/"), true)
  T.expect.equality(vim.tbl_contains(completions, "/home/user/documents/"), true)
  T.expect.equality(vim.tbl_contains(completions, "/tmp/"), true)

  -- Test with short form -C
  completions = codex.get_command_completions("", "codex -C ", 9)
  T.expect.equality(vim.tbl_contains(completions, "/home/user/projects/"), true)

  vim.fn.getcompletion = original_getcompletion
end

-- Test Codex image file completions
test_set["Codex image file completions"] = function()
  local codex = require("aibo.integration.codex")

  -- Mock getcompletion for files
  local original_getcompletion = vim.fn.getcompletion
  vim.fn.getcompletion = function(arg, type)
    if type == "file" then
      return { "image1.png", "image2.jpg", "document.pdf" }
    end
    return {}
  end

  -- Test --image completion
  local completions = codex.get_command_completions("", "codex --image ", 14)
  T.expect.equality(vim.tbl_contains(completions, "image1.png"), true)
  T.expect.equality(vim.tbl_contains(completions, "image2.jpg"), true)
  T.expect.equality(vim.tbl_contains(completions, "document.pdf"), true)

  -- Test with short form -i
  completions = codex.get_command_completions("", "codex -i ", 9)
  T.expect.equality(vim.tbl_contains(completions, "image1.png"), true)

  vim.fn.getcompletion = original_getcompletion
end

-- Test Codex flags without values
test_set["Codex flags without values"] = function()
  local codex = require("aibo.integration.codex")

  -- Test --ask-for-approval flag which doesn't take a value
  local completions = codex.get_command_completions("--as", "codex --as", 10)
  T.expect.equality(vim.tbl_contains(completions, "--ask-for-approval"), true)

  -- Test --full-auto flag which doesn't take a value
  completions = codex.get_command_completions("--fu", "codex --fu", 10)
  T.expect.equality(vim.tbl_contains(completions, "--full-auto"), true)

  -- After --full-auto, should still complete other arguments
  completions = codex.get_command_completions("", "codex --full-auto ", 18)
  T.expect.equality(vim.tbl_contains(completions, "--model"), true)
  T.expect.equality(vim.tbl_contains(completions, "--image"), true)
end

-- Test Codex mixed arguments
test_set["Codex mixed arguments"] = function()
  local codex = require("aibo.integration.codex")

  -- Test completion after model is specified
  local completions = codex.get_command_completions("", "codex --model gpt-4 ", 20)
  T.expect.equality(vim.tbl_contains(completions, "--ask-for-approval"), true)
  T.expect.equality(vim.tbl_contains(completions, "--full-auto"), true)
  T.expect.equality(vim.tbl_contains(completions, "--image"), true)

  -- Test completion after multiple arguments
  completions = codex.get_command_completions("", "codex --model gpt-4 --full-auto ", 33)
  T.expect.equality(vim.tbl_contains(completions, "--image"), true)
  T.expect.equality(vim.tbl_contains(completions, "--cd"), true)
end

-- Test check_health function
test_set["Codex check_health"] = function()
  local codex = require("aibo.integration.codex")

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
    codex = true,
    node = true,
  })

  -- Mock env variable
  local original_env = vim.env.OPENAI_API_KEY
  vim.env.OPENAI_API_KEY = "test-key"

  -- Run health check
  codex.check_health(reporter)

  -- Check that appropriate messages were reported
  T.expect.equality(reports[1].type, "start")
  T.expect.equality(reports[1].msg:find("Codex") ~= nil, true)

  -- Should report that codex is found
  local has_ok_report = false
  for _, report in ipairs(reports) do
    if report.type == "ok" and report.msg:find("codex CLI found") then
      has_ok_report = true
      break
    end
  end
  T.expect.equality(has_ok_report, true)

  -- Restore
  vim.env.OPENAI_API_KEY = original_env
  restore()
end

return test_set
