local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

local function fake_probe_cmd()
  local this = debug.getinfo(1, "S").source:sub(2)
  local dir = vim.fn.fnamemodify(this, ":h")
  return { vim.v.progpath, "-l", dir .. "/fixtures/fake_claude_probe.lua" }
end

local function index_by_cmd(entries)
  local set = {}
  for _, e in ipairs(entries or {}) do
    set[e.cmd] = e
  end
  return set
end

-- _parse_available_commands / resolve_cmd (pure) -----------------------------

T["_parse_available_commands maps name/description into entries"] = function()
  local completion = require("aibo.completion.claude")
  local entries = completion._parse_available_commands({
    { name = "help", description = "Show help" },
  })
  eq(#entries, 1)
  eq(entries[1].cmd, "/help")
  eq(entries[1].description, "Show help")
end

T["_parse_available_commands tolerates missing description"] = function()
  local completion = require("aibo.completion.claude")
  local entries = completion._parse_available_commands({ { name = "solo" } })
  eq(#entries, 1)
  eq(entries[1].description, "")
end

T["_parse_available_commands skips malformed entries"] = function()
  local completion = require("aibo.completion.claude")
  local entries = completion._parse_available_commands({
    { name = "ok", description = "fine" },
    { description = "no name" },
    "garbage",
  })
  eq(#entries, 1)
  eq(entries[1].cmd, "/ok")
end

T["resolve_cmd returns nil for a non-executable explicit cmd"] = function()
  local completion = require("aibo.completion.claude")
  eq(completion.resolve_cmd({ cmd = { "aibo-nonexistent-claude-xyz" } }), nil)
  eq(completion.is_available({ cmd = { "aibo-nonexistent-claude-xyz" } }), false)
end

-- get_commands / omnifunc without a populated probe cache ---------------------
-- There is no static fallback: with no live probe cached, completion offers
-- nothing.

local E = helpers.new_set({
  hooks = {
    pre_case = function()
      package.loaded["aibo.completion.claude"] = nil
      require("aibo.completion.claude").clear_cache()
    end,
    post_case = function()
      local completion = package.loaded["aibo.completion.claude"]
      if completion then
        completion.clear_cache()
      end
      package.loaded["aibo.completion.claude"] = nil
    end,
  },
})
T["no probe cached"] = E

E["get_commands returns an empty list"] = function()
  local completion = require("aibo.completion.claude")
  eq(completion.get_commands(), {})
end

E["omnifunc returns no slash completions"] = function()
  local completion = require("aibo.completion.claude")
  eq(completion.omnifunc(0, "/"), {})
end

-- get_commands / omnifunc against a populated probe cache ---------------------

local P = helpers.new_set({
  hooks = {
    pre_case = function()
      package.loaded["aibo.completion.claude"] = nil
      local completion = require("aibo.completion.claude")
      completion.clear_cache()

      local cwd = vim.fn.getcwd()
      local called
      completion.refresh_acp({ cmd = fake_probe_cmd(), cwd = cwd, timeout = 5000 }, function()
        called = true
      end)
      local ok = vim.wait(8000, function()
        return called == true
      end, 50)
      eq(ok, true)
    end,
    post_case = function()
      local completion = package.loaded["aibo.completion.claude"]
      if completion then
        completion.clear_cache()
      end
      package.loaded["aibo.completion.claude"] = nil
    end,
  },
})
T["probed"] = P

P["get_commands returns the probed list"] = function()
  local completion = require("aibo.completion.claude")
  local set = index_by_cmd(completion.get_commands())

  eq(set["/help"] ~= nil, true)
  eq(set["/help"].description, "Show help and available commands")
  eq(set["/model"] ~= nil, true)
  eq(set["/acp-only-marker"] ~= nil, true)
  -- command with no description survives with an empty string
  eq(set["/no-desc"] ~= nil, true)
  eq(set["/no-desc"].description, "")
  -- malformed (non-table) entry is dropped
  eq(set["/garbage-string"], nil)
end

P["omnifunc returns completions for slash prefix"] = function()
  local completion = require("aibo.completion.claude")
  local completions = completion.omnifunc(0, "/")
  eq(type(completions), "table")
  eq(#completions > 0, true)
  for _, item in ipairs(completions) do
    eq(item.word:sub(1, 1), "/")
    eq(item.kind, "Slash")
  end
end

P["omnifunc filters completions by prefix"] = function()
  local completion = require("aibo.completion.claude")
  local completions = completion.omnifunc(0, "/he")

  for _, item in ipairs(completions) do
    eq(item.word:sub(1, 3):lower(), "/he")
  end

  local has_help = false
  for _, item in ipairs(completions) do
    if item.word == "/help" then
      has_help = true
    end
  end
  eq(has_help, true)
end

P["omnifunc adds leading slash if missing"] = function()
  local completion = require("aibo.completion.claude")
  local completions = completion.omnifunc(0, "he")

  local has_help = false
  for _, item in ipairs(completions) do
    if item.word == "/help" then
      has_help = true
    end
  end
  eq(has_help, true)
end

P["omnifunc routes @ prefix to file completion"] = function()
  local completion = require("aibo.completion.claude")
  local completions = completion.omnifunc(0, "@")

  for _, item in ipairs(completions) do
    eq(item.kind == "File" or item.kind == "Dir", true)
    eq(item.word:sub(1, 1), "@")
  end
end

P["omnifunc routes @/ to file completion over slash"] = function()
  local completion = require("aibo.completion.claude")
  local completions = completion.omnifunc(0, "@/")

  for _, item in ipairs(completions) do
    eq(item.kind == "File" or item.kind == "Dir", true)
  end
end

return T
