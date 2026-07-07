local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

local function fake_acp_cmd()
  local this = debug.getinfo(1, "S").source:sub(2)
  local dir = vim.fn.fnamemodify(this, ":h")
  return { vim.v.progpath, "-l", dir .. "/fixtures/fake_acp.lua" }
end

local function index_by_cmd(entries)
  local set = {}
  for _, e in ipairs(entries or {}) do
    set[e.cmd] = e
  end
  return set
end

-- resolve_cmd / is_available --------------------------------------------------

T["resolve_cmd returns nil for a non-executable explicit cmd"] = function()
  local completion = require("aibo.completion.gemini")
  eq(completion.resolve_cmd({ cmd = { "aibo-nonexistent-gemini-xyz" } }), nil)
end

T["resolve_cmd returns an explicit cmd when it is executable"] = function()
  local completion = require("aibo.completion.gemini")
  local cmd = { vim.v.progpath }
  eq(completion.resolve_cmd({ cmd = cmd }), cmd)
end

-- refresh_acp / get_commands / omnifunc against the fake ACP responder -------

local R = helpers.new_set({
  hooks = {
    pre_case = function()
      package.loaded["aibo.completion.gemini"] = nil
      package.loaded["aibo.completion.acp"] = nil
      require("aibo.completion.acp").clear_cache()
    end,
    post_case = function()
      local acp = package.loaded["aibo.completion.acp"]
      if acp then
        acp.clear_cache()
      end
      package.loaded["aibo.completion.gemini"] = nil
      package.loaded["aibo.completion.acp"] = nil
    end,
  },
})
T["probe"] = R

R["get_commands is empty until the ACP cache is populated"] = function()
  local completion = require("aibo.completion.gemini")
  eq(completion.get_commands(), {})
end

R["refresh_acp populates the cache and get_commands reflects it"] = function()
  local completion = require("aibo.completion.gemini")
  local cwd = vim.fn.getcwd()

  local called
  completion.refresh_acp({ cmd = fake_acp_cmd(), cwd = cwd, timeout = 5000 }, function()
    called = true
  end)
  local ok = vim.wait(8000, function()
    return called == true
  end, 50)
  eq(ok, true)

  local set = index_by_cmd(completion.get_commands())
  eq(set["/acp-only-marker"] ~= nil, true)
  eq(set["/acp-only-marker"].description, "Only delivered via ACP")

  local cached = completion.get_cached(cwd)
  eq(cached ~= nil, true)
end

-- omnifunc --------------------------------------------------------------

T["omnifunc returns table for slash prefix"] = function()
  local completion = require("aibo.completion.gemini")
  local completions = completion.omnifunc(0, "/")
  eq(type(completions), "table")
end

return T
