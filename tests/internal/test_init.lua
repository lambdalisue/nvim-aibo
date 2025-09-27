-- Tests for aibo/init.lua

local T = require("mini.test")

-- Test set
local test_set = T.new_set({
  hooks = {
    post_case = function()
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

-- Test setup function
test_set["setup function"] = function()
  -- Force reload to get clean state
  package.loaded["aibo"] = nil
  local aibo = require("aibo")

  -- Test default setup
  aibo.setup()
  local config = aibo.get_config()
  T.expect.equality(config.submit_delay, 100)
  T.expect.equality(config.prompt_height, 10)

  -- Test custom setup
  aibo.setup({
    submit_delay = 200,
    prompt_height = 15,
  })
  config = aibo.get_config()
  T.expect.equality(config.submit_delay, 200)
  T.expect.equality(config.prompt_height, 15)

  -- Test partial updates
  aibo.setup({
    submit_delay = 300,
  })
  config = aibo.get_config()
  T.expect.equality(config.submit_delay, 300)
  T.expect.equality(config.prompt_height, 15) -- Should remain unchanged
end

-- Test buffer config functions
test_set["get_buffer_config"] = function()
  local aibo = require("aibo")

  -- Setup with prompt configuration
  aibo.setup({
    prompt = {
      no_default_mappings = true,
      custom_prompt_option = "prompt_value",
    },
    console = {
      no_default_mappings = false,
      custom_console_option = "console_value",
    },
    tools = {
      claude = {
        no_default_mappings = false,
        custom_tool_option = "tool_value",
      },
    },
  })

  -- Test that get_buffer_config only returns buffer type config
  local prompt_config = aibo.get_buffer_config("prompt")
  T.expect.equality(prompt_config.no_default_mappings, true)
  T.expect.equality(prompt_config.custom_prompt_option, "prompt_value")
  T.expect.equality(prompt_config.custom_tool_option, nil) -- Should not have tool config

  -- Test console buffer config
  local console_config = aibo.get_buffer_config("console")
  T.expect.equality(console_config.no_default_mappings, false)
  T.expect.equality(console_config.custom_console_option, "console_value")
  T.expect.equality(console_config.custom_tool_option, nil) -- Should not have tool config
end

-- Test tool config functions
test_set["get_tool_config"] = function()
  local aibo = require("aibo")

  aibo.setup({
    tools = {
      claude = {
        no_default_mappings = true,
        custom_option = "test",
      },
      codex = {
        no_default_mappings = false,
      },
    },
  })

  -- Test claude config
  local claude_config = aibo.get_tool_config("claude")
  T.expect.equality(claude_config.no_default_mappings, true)
  T.expect.equality(claude_config.custom_option, "test")

  -- Test codex config
  local codex_config = aibo.get_tool_config("codex")
  T.expect.equality(codex_config.no_default_mappings, false)

  -- Test unknown tool (should return empty table)
  local unknown_config = aibo.get_tool_config("unknown")
  T.expect.equality(vim.tbl_count(unknown_config), 0)
end

-- Test send function
test_set["send function"] = function()
  local aibo = require("aibo")

  -- Create a terminal buffer
  local buf = vim.api.nvim_create_buf(false, true)
  local chan = vim.api.nvim_open_term(buf, {})

  -- Mock the buffer to have a terminal channel
  vim.b[buf].terminal_job_id = chan

  -- Test sending data
  local ok = pcall(aibo.send, "test\n", buf)
  T.expect.equality(ok, true)
end

-- Test submit function
test_set["submit function"] = function()
  local aibo = require("aibo")

  -- Create a terminal buffer
  local buf = vim.api.nvim_create_buf(false, true)
  local chan = vim.api.nvim_open_term(buf, {})

  -- Mock the buffer to have a terminal channel
  vim.b[buf].terminal_job_id = chan

  -- Setup with custom delay
  aibo.setup({ submit_delay = 50 })

  -- Test submitting data
  local ok = pcall(aibo.submit, "test message", buf)
  T.expect.equality(ok, true)
end

-- Test configuration merging
test_set["configuration merging"] = function()
  local aibo = require("aibo")

  -- First setup
  aibo.setup({
    submit_delay = 150,
    prompt = {
      no_default_mappings = true,
      on_attach = function() end,
    },
    tools = {
      claude = {
        custom_option = "value1",
      },
    },
  })

  -- Second setup should merge
  aibo.setup({
    prompt_height = 20,
    tools = {
      claude = {
        another_option = "value2",
      },
      codex = {
        new_option = "value3",
      },
    },
  })

  local config = aibo.get_config()

  -- Check merged values
  T.expect.equality(config.submit_delay, 150) -- From first setup
  T.expect.equality(config.prompt_height, 20) -- From second setup
  T.expect.equality(config.prompt.no_default_mappings, true) -- From first setup
  T.expect.equality(config.tools.claude.custom_option, "value1") -- From first setup
  T.expect.equality(config.tools.claude.another_option, "value2") -- From second setup
  T.expect.equality(config.tools.codex.new_option, "value3") -- From second setup
end

-- Test termcode export
test_set["termcode module is exported"] = function()
  local aibo = require("aibo")

  -- Check that termcode is exposed
  T.expect.equality(type(aibo.termcode), "table", "termcode should be a table")
  T.expect.equality(type(aibo.termcode.resolve), "function", "termcode.resolve should be a function")

  -- Basic functionality test
  local result = aibo.termcode.resolve("<C-w>")
  T.expect.equality(type(result), "string", "resolve should return a string")
end

-- Test integration export
test_set["integration module is exported"] = function()
  local aibo = require("aibo")

  -- Check that integration is exposed
  T.expect.equality(type(aibo.integration), "table", "integration should be a table")

  -- Check that integration provides the expected API
  T.expect.equality(type(aibo.integration.get_module), "function", "integration.get_module should be a function")
  T.expect.equality(
    type(aibo.integration.available_integrations),
    "function",
    "integration.available_integrations should be a function"
  )
  T.expect.equality(type(aibo.integration.is_available), "function", "integration.is_available should be a function")
  T.expect.equality(type(aibo.integration.check_health), "function", "integration.check_health should be a function")

  -- Check that available_integrations returns expected tools
  local integrations = aibo.integration.available_integrations()
  T.expect.equality(type(integrations), "table", "available_integrations should return a table")
  T.expect.equality(vim.tbl_contains(integrations, "claude"), true, "Should include claude")
  T.expect.equality(vim.tbl_contains(integrations, "codex"), true, "Should include codex")
  T.expect.equality(vim.tbl_contains(integrations, "ollama"), true, "Should include ollama")
end

return test_set
