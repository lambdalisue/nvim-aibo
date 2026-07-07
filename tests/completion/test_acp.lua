local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Path to the fake ACP adapter fixture, resolved relative to this test file.
local function fake_adapter_cmd()
  local this = debug.getinfo(1, "S").source:sub(2)
  local dir = vim.fn.fnamemodify(this, ":h")
  local fake = dir .. "/fixtures/fake_acp.lua"
  return { vim.v.progpath, "-l", fake }
end

local function index_by_cmd(entries)
  local set = {}
  for _, e in ipairs(entries or {}) do
    set[e.cmd] = e
  end
  return set
end

-- _parse_available_commands (pure) -----------------------------------------

T["_parse_available_commands maps name/description into entries"] = function()
  local acp = require("aibo.completion.acp")
  local entries = acp._parse_available_commands({
    { name = "help", description = "Show help" },
    { name = "clear", description = "Clear" },
  })
  eq(#entries, 2)
  local set = index_by_cmd(entries)
  eq(set["/help"].description, "Show help")
  eq(set["/clear"].description, "Clear")
end

T["_parse_available_commands tolerates missing description"] = function()
  local acp = require("aibo.completion.acp")
  local entries = acp._parse_available_commands({ { name = "solo" } })
  eq(#entries, 1)
  eq(entries[1].cmd, "/solo")
  eq(entries[1].description, "")
end

T["_parse_available_commands skips malformed entries"] = function()
  local acp = require("aibo.completion.acp")
  local entries = acp._parse_available_commands({
    { name = "ok", description = "fine" },
    { description = "no name" },
    { name = "" },
    "garbage",
    42,
  })
  eq(#entries, 1)
  eq(entries[1].cmd, "/ok")
end

T["_parse_available_commands handles nil/empty"] = function()
  local acp = require("aibo.completion.acp")
  eq(acp._parse_available_commands(nil), {})
  eq(acp._parse_available_commands({}), {})
end

-- cache ---------------------------------------------------------------------

T["get_cached returns nil on miss"] = function()
  local acp = require("aibo.completion.acp")
  acp.clear_cache()
  eq(acp.get_cached("/no/such/dir/for/aibo/test"), nil)
end

-- resolve_cmd / is_available ------------------------------------------------
-- This client is agent-agnostic: there is no default command, so `cmd` must
-- always be supplied explicitly.

T["resolve_cmd returns an explicit cmd when it is executable"] = function()
  local acp = require("aibo.completion.acp")
  local cmd = { vim.v.progpath } -- nvim itself is always executable
  eq(acp.resolve_cmd({ cmd = cmd }), cmd)
  eq(acp.is_available({ cmd = cmd }), true)
end

T["resolve_cmd returns nil for a non-executable explicit cmd"] = function()
  local acp = require("aibo.completion.acp")
  eq(acp.resolve_cmd({ cmd = { "aibo-nonexistent-acp-agent-xyz" } }), nil)
  eq(acp.is_available({ cmd = { "aibo-nonexistent-acp-agent-xyz" } }), false)
end

T["resolve_cmd returns nil when cmd is missing"] = function()
  local acp = require("aibo.completion.acp")
  eq(acp.resolve_cmd({}), nil)
  eq(acp.resolve_cmd(nil), nil)
end

-- refresh against the fake adapter ------------------------------------------

local R = helpers.new_set({
  hooks = {
    pre_case = function()
      package.loaded["aibo.completion.acp"] = nil
    end,
    post_case = function()
      local acp = package.loaded["aibo.completion.acp"]
      if acp then
        acp.clear_cache()
      end
      package.loaded["aibo.completion.acp"] = nil
    end,
  },
})
T["refresh"] = R

R["fetches and caches commands from a fake ACP adapter"] = function()
  local acp = require("aibo.completion.acp")
  local cwd = vim.fn.getcwd()

  local result, err, called
  acp.refresh({ cmd = fake_adapter_cmd(), cwd = cwd, timeout = 5000 }, function(entries, e)
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
  eq(set["/help"].description, "Show help and available commands")
  eq(set["/model"] ~= nil, true)
  -- command with no description survives with an empty string
  eq(set["/no-desc"] ~= nil, true)
  eq(set["/no-desc"].description, "")
  -- malformed (non-table) entry is dropped
  eq(set["/garbage-string"], nil)

  -- result is cached for the cwd
  local cached = acp.get_cached(cwd)
  eq(cached ~= nil, true)
  eq(index_by_cmd(cached)["/help"] ~= nil, true)
end

R["reports an error when the agent command is missing"] = function()
  local acp = require("aibo.completion.acp")

  local result, err, called
  acp.refresh({ cmd = { "aibo-nonexistent-acp-agent-xyz" }, timeout = 2000 }, function(entries, e)
    result, err, called = entries, e, true
  end)

  local ok = vim.wait(3000, function()
    return called == true
  end, 25)
  eq(ok, true)
  eq(result, nil)
  eq(type(err), "string")
end

R["ensure_and_refresh reports an error when the agent command is missing"] = function()
  local acp = require("aibo.completion.acp")

  local result, err, called
  acp.ensure_and_refresh({ cmd = { "aibo-nonexistent-acp-agent-xyz" } }, function(entries, e)
    result, err, called = entries, e, true
  end)

  eq(called, true) -- synchronous: resolved before any process is spawned
  eq(result, nil)
  eq(type(err), "string")
end

return T
