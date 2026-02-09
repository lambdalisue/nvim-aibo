local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Reset history module between tests
local function reset_history()
  package.loaded["aibo.internal.history"] = nil
  return require("aibo.internal.history")
end

T["add stores content in history"] = function()
  local history = reset_history()

  history.add("first")
  history.add("second")
  history.add("third")

  eq(history.count(), 3)
end

T["add ignores empty content"] = function()
  local history = reset_history()

  history.add("")
  history.add("   ")
  history.add("\n\t")

  eq(history.count(), 0)
end

T["add ignores duplicate consecutive entries"] = function()
  local history = reset_history()

  history.add("hello")
  history.add("hello")
  history.add("world")
  history.add("hello") -- Not consecutive duplicate

  eq(history.count(), 3)
end

T["prev returns previous history entry"] = function()
  local history = reset_history()
  local bufnr = 999

  history.add("first")
  history.add("second")
  history.add("third")

  -- Create a mock buffer
  local original_set_lines = vim.api.nvim_buf_set_lines
  local original_get_lines = vim.api.nvim_buf_get_lines
  vim.api.nvim_buf_set_lines = function()
    return {}
  end
  vim.api.nvim_buf_get_lines = function()
    return { "" }
  end

  local result = history.prev(bufnr)
  eq(result, { "third" })

  result = history.prev(bufnr)
  eq(result, { "second" })

  result = history.prev(bufnr)
  eq(result, { "first" })

  -- At oldest entry
  result = history.prev(bufnr)
  eq(result, nil)

  -- Restore
  vim.api.nvim_buf_set_lines = original_set_lines
  vim.api.nvim_buf_get_lines = original_get_lines
end

T["next returns next history entry"] = function()
  local history = reset_history()
  local bufnr = 999

  history.add("first")
  history.add("second")

  local original_get_lines = vim.api.nvim_buf_get_lines
  vim.api.nvim_buf_get_lines = function()
    return { "draft" }
  end

  -- Go back
  history.prev(bufnr)
  history.prev(bufnr)

  -- Go forward
  local result = history.next(bufnr)
  eq(result, { "second" })

  result = history.next(bufnr)
  eq(result, { "draft" }) -- Returns to draft

  result = history.next(bufnr)
  eq(result, nil) -- Already at newest

  -- Restore
  vim.api.nvim_buf_get_lines = original_get_lines
end

T["clear_state resets navigation"] = function()
  local history = reset_history()
  local bufnr = 999

  history.add("first")

  local original_get_lines = vim.api.nvim_buf_get_lines
  vim.api.nvim_buf_get_lines = function()
    return { "" }
  end

  history.prev(bufnr)
  eq(history.get_index(bufnr), 1)

  history.clear_state(bufnr)
  eq(history.get_index(bufnr), nil)

  -- Restore
  vim.api.nvim_buf_get_lines = original_get_lines
end

T["prev preserves draft content"] = function()
  local history = reset_history()
  local bufnr = 999

  history.add("history entry")

  -- Mock buffer with draft content
  local original_get_lines = vim.api.nvim_buf_get_lines
  vim.api.nvim_buf_get_lines = function()
    return { "my draft", "content" }
  end

  -- Navigate to history
  local result = history.prev(bufnr)
  eq(result, { "history entry" })

  -- Navigate back to draft
  result = history.next(bufnr)
  eq(result, { "my draft", "content" })

  -- Restore
  vim.api.nvim_buf_get_lines = original_get_lines
end

T["handles multiline content"] = function()
  local history = reset_history()
  local bufnr = 999

  history.add("line1\nline2\nline3")

  local original_get_lines = vim.api.nvim_buf_get_lines
  vim.api.nvim_buf_get_lines = function()
    return { "" }
  end

  local result = history.prev(bufnr)
  eq(result, { "line1", "line2", "line3" })

  -- Restore
  vim.api.nvim_buf_get_lines = original_get_lines
end

return T
