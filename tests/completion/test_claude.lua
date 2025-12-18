local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Test getting slash command completions
T["get_commands returns all commands"] = function()
  local completion = require("aibo.completion.claude")

  local commands = completion.get_commands()
  eq(type(commands), "table")
  eq(#commands > 0, true)

  -- Check that each command has the expected structure
  for _, cmd in ipairs(commands) do
    eq(type(cmd.cmd), "string")
    eq(type(cmd.description), "string")
    eq(cmd.cmd:sub(1, 1), "/")
  end
end

-- Test omnifunc completion mode
T["omnifunc returns completions for slash prefix"] = function()
  local completion = require("aibo.completion.claude")

  local completions = completion.omnifunc(0, "/")
  eq(type(completions), "table")
  eq(#completions > 0, true)

  -- All completions should start with "/"
  for _, item in ipairs(completions) do
    eq(item.word:sub(1, 1), "/")
  end
end

-- Test omnifunc filtering
T["omnifunc filters completions by prefix"] = function()
  local completion = require("aibo.completion.claude")

  local completions = completion.omnifunc(0, "/he")
  eq(type(completions), "table")

  -- All returned completions should start with "/he"
  for _, item in ipairs(completions) do
    eq(item.word:sub(1, 3):lower(), "/he")
  end

  -- Should include /help
  local has_help = false
  for _, item in ipairs(completions) do
    if item.word == "/help" then
      has_help = true
      break
    end
  end
  eq(has_help, true)
end

-- Test specific commands exist
T["known slash commands are present"] = function()
  local completion = require("aibo.completion.claude")

  local commands = completion.get_commands()
  local cmd_set = {}
  for _, cmd in ipairs(commands) do
    cmd_set[cmd.cmd] = true
  end

  -- Check some known commands
  eq(cmd_set["/help"], true)
  eq(cmd_set["/clear"], true)
  eq(cmd_set["/model"], true)
  eq(cmd_set["/resume"], true)
  eq(cmd_set["/compact"], true)
end

-- Test completion item structure
T["completion items have correct structure"] = function()
  local completion = require("aibo.completion.claude")

  local completions = completion.omnifunc(0, "/")
  eq(#completions > 0, true)

  local item = completions[1]
  eq(type(item.word), "string")
  eq(type(item.menu), "string")
  eq(item.kind, "Slash")
end

-- Test that omnifunc handles base without leading slash
T["omnifunc adds leading slash if missing"] = function()
  local completion = require("aibo.completion.claude")

  local completions = completion.omnifunc(0, "he")
  eq(type(completions), "table")

  -- Should still find /help
  local has_help = false
  for _, item in ipairs(completions) do
    if item.word == "/help" then
      has_help = true
      break
    end
  end
  eq(has_help, true)
end

return T
