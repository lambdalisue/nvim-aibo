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

-- Test that omnifunc routes @ prefix to file completion
T["omnifunc routes @ prefix to file completion"] = function()
  local completion = require("aibo.completion.claude")

  local completions = completion.omnifunc(0, "@")
  eq(type(completions), "table")

  -- All completions should be files/dirs, not slash commands
  for _, item in ipairs(completions) do
    eq(item.kind == "File" or item.kind == "Dir", true)
    eq(item.word:sub(1, 1), "@")
  end
end

-- Test that omnifunc routes @/ prefix to file completion (not slash)
T["omnifunc routes @/ to file completion over slash"] = function()
  local completion = require("aibo.completion.claude")

  -- "@/" contains "/" but should route to file completion, not slash commands
  local completions = completion.omnifunc(0, "@/")
  eq(type(completions), "table")

  -- Should NOT contain slash commands
  for _, item in ipairs(completions) do
    eq(item.kind == "File" or item.kind == "Dir", true)
  end
end

-- Test that slash commands still work when @ routing is present
T["omnifunc still returns slash commands for / prefix"] = function()
  local completion = require("aibo.completion.claude")

  local completions = completion.omnifunc(0, "/")
  eq(type(completions), "table")
  eq(#completions > 0, true)

  -- All completions should be slash commands
  for _, item in ipairs(completions) do
    eq(item.kind, "Slash")
    eq(item.word:sub(1, 1), "/")
  end
end

-- Skills discovery tests
local S = helpers.new_set({
  hooks = {
    pre_case = function()
      -- Create temp .claude/skills directory in cwd
      -- Skills use <skill-name>/SKILL.md structure
      local skills_dir = vim.fn.getcwd() .. "/.claude/skills"

      -- Skill with YAML front matter
      vim.fn.mkdir(skills_dir .. "/tdd-workflow", "p")
      vim.fn.writefile({
        "---",
        "description: Run tests in TDD style",
        "---",
        "Run tests using TDD workflow",
      }, skills_dir .. "/tdd-workflow/SKILL.md")

      -- Skill without front matter
      vim.fn.mkdir(skills_dir .. "/git-commit", "p")
      vim.fn.writefile({
        "# Create a conventional commit",
        "Help create a commit message",
      }, skills_dir .. "/git-commit/SKILL.md")

      -- Clear module cache to pick up new skills
      package.loaded["aibo.completion.claude"] = nil
    end,
    post_case = function()
      -- Clean up temp skills directory
      vim.fn.delete(vim.fn.getcwd() .. "/.claude/skills", "rf")
      package.loaded["aibo.completion.claude"] = nil
    end,
  },
})
T["skills"] = S

S["discovers skills from .claude/skills directory"] = function()
  local completion = require("aibo.completion.claude")

  local commands = completion.get_commands()
  local cmd_set = {}
  for _, cmd in ipairs(commands) do
    cmd_set[cmd.cmd] = cmd
  end

  eq(cmd_set["/tdd-workflow"] ~= nil, true)
  eq(cmd_set["/tdd-workflow"].description, "Run tests in TDD style (skill)")
end

S["extracts description from first line when no front matter"] = function()
  local completion = require("aibo.completion.claude")

  local commands = completion.get_commands()
  local cmd_set = {}
  for _, cmd in ipairs(commands) do
    cmd_set[cmd.cmd] = cmd
  end

  eq(cmd_set["/git-commit"] ~= nil, true)
  eq(cmd_set["/git-commit"].description, "Create a conventional commit (skill)")
end

S["skills appear in omnifunc completions"] = function()
  local completion = require("aibo.completion.claude")

  local completions = completion.omnifunc(0, "/tdd")
  eq(type(completions), "table")

  local has_tdd = false
  for _, item in ipairs(completions) do
    if item.word == "/tdd-workflow" then
      has_tdd = true
      break
    end
  end
  eq(has_tdd, true)
end

return T
