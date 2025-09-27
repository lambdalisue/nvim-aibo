-- Tests for plugin setup and loading (plugin/aibo.lua)

local T = require("mini.test")

-- Test set
local test_set = T.new_set({
  hooks = {
    post_case = function()
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

-- Test plugin loading guard
test_set["Plugin loading guard"] = function()
  -- First load should work
  vim.g.loaded_aibo = nil
  vim.cmd("runtime plugin/aibo.lua")
  T.expect.equality(vim.g.loaded_aibo, 1)

  -- Second load should be blocked
  local before_cmds = vim.api.nvim_get_commands({})
  vim.cmd("runtime plugin/aibo.lua")
  local after_cmds = vim.api.nvim_get_commands({})

  -- Command count should remain the same
  T.expect.equality(vim.tbl_count(before_cmds), vim.tbl_count(after_cmds))
end

-- Test Aibo command existence
test_set["Aibo command exists"] = function()
  vim.g.loaded_aibo = nil
  vim.cmd("runtime plugin/aibo.lua")

  local commands = vim.api.nvim_get_commands({})
  T.expect.equality(commands["Aibo"] ~= nil, true, "Aibo command should exist")
  T.expect.equality(commands["Aibo"].nargs, "+", "Aibo should accept 1+ args")
end

-- Test AiboSend command existence
test_set["AiboSend command exists"] = function()
  vim.g.loaded_aibo = nil
  vim.cmd("runtime plugin/aibo.lua")

  local commands = vim.api.nvim_get_commands({})
  T.expect.equality(commands["AiboSend"] ~= nil, true, "AiboSend command should exist")
  T.expect.equality(commands["AiboSend"].nargs, "*", "AiboSend should accept 0+ args")
  T.expect.equality(commands["AiboSend"].range ~= nil, true, "AiboSend should support range")
end

return test_set
