local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Test setup function
T["setup function"] = function()
  -- Force reload to get clean state
  package.loaded["aibo"] = nil
  local aibo = require("aibo")

  -- Test default setup
  aibo.setup()
  local config = aibo.get_config()
  eq(config.submit_delay, 500)
  eq(config.prompt_height, 10)

  -- Test custom setup
  aibo.setup({
    submit_delay = 200,
    prompt_height = 15,
  })
  config = aibo.get_config()
  eq(config.submit_delay, 200)
  eq(config.prompt_height, 15)

  -- Test partial updates
  aibo.setup({
    submit_delay = 300,
  })
  config = aibo.get_config()
  eq(config.submit_delay, 300)
  eq(config.prompt_height, 15) -- Should remain unchanged
end

-- Test buffer config functions
T["get_buffer_config"] = function()
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
  eq(prompt_config.no_default_mappings, true)
  eq(prompt_config.custom_prompt_option, "prompt_value")
  eq(prompt_config.custom_tool_option, nil) -- Should not have tool config

  -- Test console buffer config
  local console_config = aibo.get_buffer_config("console")
  eq(console_config.no_default_mappings, false)
  eq(console_config.custom_console_option, "console_value")
  eq(console_config.custom_tool_option, nil) -- Should not have tool config
end

-- Test tool config functions
T["get_tool_config"] = function()
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
  eq(claude_config.no_default_mappings, true)
  eq(claude_config.custom_option, "test")

  -- Test codex config
  local codex_config = aibo.get_tool_config("codex")
  eq(codex_config.no_default_mappings, false)

  -- Test unknown tool (should return empty table)
  local unknown_config = aibo.get_tool_config("unknown")
  eq(vim.tbl_count(unknown_config), 0)
end

-- Test the live-completion defaults and enable/disable behavior. Completion
-- config lives under tools.<tool>.completion.<source> so it can vary per
-- tool profile, not as a single global list.
-- Reload aibo first so the default assertions do not depend on earlier tests
-- (setup() is incremental and mutates the shared module config).
T["completion config defaults and override"] = function()
  package.loaded["aibo"] = nil
  local aibo = require("aibo")

  -- Default: all three are on (none has a static fallback to preserve).
  aibo.setup()
  eq(aibo.get_completion_config("claude", "claude"), true)
  eq(aibo.get_completion_config("codex", "codex"), true)
  eq(aibo.get_completion_config("gemini", "acp"), true)
  eq(aibo.get_completion_config("claude", "unknown"), false)
  eq(aibo.get_completion_config("unknown", "claude"), false)

  -- Enabling with a config table takes effect (cmd/timeout default downstream)
  aibo.setup({ tools = { claude = { completion = { claude = { timeout = 5000 } } } } })
  local c2 = aibo.get_completion_config("claude", "claude")
  eq(type(c2), "table")
  eq(c2.timeout, 5000)

  -- Explicit false disables again
  aibo.setup({ tools = { claude = { completion = { claude = false } } } })
  eq(aibo.get_completion_config("claude", "claude"), false)

  -- A custom tool profile can opt into any completion source/module, not
  -- just the one matching its own name (e.g. a custom "ollama" wrapper that
  -- launches a claude-flavored model could set completion.claude = true).
  aibo.setup({ tools = { ["ollama-claude"] = { completion = { claude = true } } } })
  eq(aibo.get_completion_config("ollama-claude", "claude"), true)
end

-- Test send function
T["send function"] = function()
  local aibo = require("aibo")

  -- Create a terminal buffer
  local buf = vim.api.nvim_create_buf(false, true)
  local chan = vim.api.nvim_open_term(buf, {})

  -- Mock the buffer to have a terminal channel
  vim.b[buf].terminal_job_id = chan

  -- Test sending data
  local ok = pcall(aibo.send, "test\n", buf)
  eq(ok, true)
end

-- Test submit function
T["submit function"] = function()
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
  eq(ok, true)
end

-- Test configuration merging
T["configuration merging"] = function()
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
  eq(config.submit_delay, 150) -- From first setup
  eq(config.prompt_height, 20) -- From second setup
  eq(config.prompt.no_default_mappings, true) -- From first setup
  eq(config.tools.claude.custom_option, "value1") -- From first setup
  eq(config.tools.claude.another_option, "value2") -- From second setup
  eq(config.tools.codex.new_option, "value3") -- From second setup
end

-- Test termcode_mode configuration
T["termcode_mode configuration"] = function()
  -- Force reload to get clean state
  package.loaded["aibo"] = nil
  local aibo = require("aibo")

  -- Test default termcode_mode
  aibo.setup()
  local config = aibo.get_config()
  eq(config.termcode_mode, "hybrid")

  -- Test setting xterm mode
  aibo.setup({
    termcode_mode = "xterm",
  })
  config = aibo.get_config()
  eq(config.termcode_mode, "xterm")

  -- Test setting csi-n mode
  aibo.setup({
    termcode_mode = "csi-n",
  })
  config = aibo.get_config()
  eq(config.termcode_mode, "csi-n")
end

-- Test aibo.resolve function
T["resolve function with termcode_mode"] = function()
  -- Force reload to get clean state
  package.loaded["aibo"] = nil
  local aibo = require("aibo")

  -- Test with default hybrid mode
  aibo.setup()
  eq(aibo.resolve("<S-Tab>"), "\27[Z") -- xterm sequence
  eq(aibo.resolve("<C-Space>"), "\0") -- xterm sequence
  eq(aibo.resolve("<C-CR>"), "\27[13;5u") -- csi-n sequence (no xterm equivalent)

  -- Test with xterm mode
  aibo.setup({
    termcode_mode = "xterm",
  })
  eq(aibo.resolve("<S-Tab>"), "\27[Z") -- xterm sequence
  eq(aibo.resolve("<C-Space>"), "\0") -- xterm sequence
  eq(aibo.resolve("<C-CR>"), nil) -- not representable in xterm

  -- Test with csi-n mode
  aibo.setup({
    termcode_mode = "csi-n",
  })
  eq(aibo.resolve("<S-Tab>"), "\27[9;2u") -- csi-n sequence
  eq(aibo.resolve("<C-Space>"), "\27[32;5u") -- csi-n sequence
  eq(aibo.resolve("<C-CR>"), "\27[13;5u") -- csi-n sequence
end

return T
