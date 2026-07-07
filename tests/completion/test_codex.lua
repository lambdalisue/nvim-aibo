local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

local function fake_probe_cmd()
  local this = debug.getinfo(1, "S").source:sub(2)
  local dir = vim.fn.fnamemodify(this, ":h")
  return { vim.v.progpath, "-l", dir .. "/fixtures/fake_codex_probe.lua" }
end

local function index_by_cmd(entries)
  local set = {}
  for _, e in ipairs(entries or {}) do
    set[e.cmd] = e
  end
  return set
end

-- _parse_skills_list (pure) -------------------------------------------------

T["_parse_skills_list flattens skills across entries"] = function()
  local completion = require("aibo.completion.codex")
  local entries = completion._parse_skills_list({
    { cwd = "/a", skills = { { name = "help", description = "Show help" } } },
    { cwd = "/b", skills = { { name = "clear", description = "Clear" } } },
  })
  eq(#entries, 2)
  local set = index_by_cmd(entries)
  eq(set["/help"].description, "Show help")
  eq(set["/clear"].description, "Clear")
end

T["_parse_skills_list tolerates missing description"] = function()
  local completion = require("aibo.completion.codex")
  local entries = completion._parse_skills_list({
    { skills = { { name = "solo" } } },
  })
  eq(#entries, 1)
  eq(entries[1].cmd, "/solo")
  eq(entries[1].description, "")
end

T["_parse_skills_list skips malformed entries"] = function()
  local completion = require("aibo.completion.codex")
  local entries = completion._parse_skills_list({
    { skills = { { name = "ok", description = "fine" }, { description = "no name" }, { name = "" }, "garbage", 42 } },
  })
  eq(#entries, 1)
  eq(entries[1].cmd, "/ok")
end

T["_parse_skills_list handles nil/empty"] = function()
  local completion = require("aibo.completion.codex")
  eq(completion._parse_skills_list(nil), {})
  eq(completion._parse_skills_list({}), {})
end

-- resolve_cmd / is_available --------------------------------------------------

T["resolve_cmd returns an explicit cmd when it is executable"] = function()
  local completion = require("aibo.completion.codex")
  local cmd = { vim.v.progpath }
  eq(completion.resolve_cmd({ cmd = cmd }), cmd)
  eq(completion.is_available({ cmd = cmd }), true)
end

T["resolve_cmd returns nil for a non-executable explicit cmd"] = function()
  local completion = require("aibo.completion.codex")
  eq(completion.resolve_cmd({ cmd = { "aibo-nonexistent-codex-xyz" } }), nil)
  eq(completion.is_available({ cmd = { "aibo-nonexistent-codex-xyz" } }), false)
end

-- refresh_acp / get_commands against the fake responder ----------------------

local R = helpers.new_set({
  hooks = {
    pre_case = function()
      package.loaded["aibo.completion.codex"] = nil
    end,
    post_case = function()
      local completion = package.loaded["aibo.completion.codex"]
      if completion then
        completion.clear_cache()
      end
      package.loaded["aibo.completion.codex"] = nil
    end,
  },
})
T["probe"] = R

R["refresh_acp fetches and caches skills from a fake codex app-server"] = function()
  local completion = require("aibo.completion.codex")
  local cwd = vim.fn.getcwd()

  local result, err, called
  completion.refresh_acp({ cmd = fake_probe_cmd(), cwd = cwd, timeout = 5000 }, function(entries, e)
    result, err, called = entries, e, true
  end)

  local ok = vim.wait(8000, function()
    return called == true
  end, 50)
  eq(ok, true)
  eq(err, nil)
  eq(type(result), "table")

  local set = index_by_cmd(result)
  eq(set["/help"] ~= nil, true)
  eq(set["/acp-only-marker"] ~= nil, true)
  eq(set["/no-desc"].description, "")
  eq(set["/garbage-string"], nil)

  local cached = completion.get_cached(cwd)
  eq(cached ~= nil, true)
  eq(index_by_cmd(cached)["/help"] ~= nil, true)
end

R["refresh_acp reports an error when codex is missing"] = function()
  local completion = require("aibo.completion.codex")

  local result, err, called
  completion.refresh_acp({ cmd = { "aibo-nonexistent-codex-xyz" }, timeout = 2000 }, function(entries, e)
    result, err, called = entries, e, true
  end)

  eq(called, true) -- synchronous: resolved before any process is spawned
  eq(result, nil)
  eq(type(err), "string")
end

R["get_commands merges the probed cache"] = function()
  local completion = require("aibo.completion.codex")
  local cwd = vim.fn.getcwd()

  local called
  completion.refresh_acp({ cmd = fake_probe_cmd(), cwd = cwd, timeout = 5000 }, function()
    called = true
  end)
  local ok = vim.wait(8000, function()
    return called == true
  end, 50)
  eq(ok, true)

  local set = index_by_cmd(completion.get_commands())
  eq(set["/acp-only-marker"] ~= nil, true)
end

-- omnifunc --------------------------------------------------------------

T["omnifunc returns table for slash prefix"] = function()
  local completion = require("aibo.completion.codex")
  local completions = completion.omnifunc(0, "/")
  eq(type(completions), "table")
end

return T
