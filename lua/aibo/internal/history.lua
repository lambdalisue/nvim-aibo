--- Input history management for aiboprompt
--- Provides functionality to store and navigate through previously submitted prompts
local M = {}

-- Global history storage (shared across all prompts)
local history = {}
local MAX_HISTORY = 100

-- Navigation state per buffer
-- Key: bufnr, Value: { index: number, draft: string[] }
local nav_state = {}

---Add content to history
---@param content string The submitted content
function M.add(content)
  -- Don't add empty content or duplicates of the last entry
  if content == "" or content:match("^%s*$") then
    return
  end
  if #history > 0 and history[#history] == content then
    return
  end

  table.insert(history, content)

  -- Trim history if it exceeds max
  while #history > MAX_HISTORY do
    table.remove(history, 1)
  end
end

---Get total history count
---@return number
function M.count()
  return #history
end

---Reset navigation state for a buffer
---@param bufnr number Buffer number
---@param draft? string[] Current buffer content to save as draft
function M.reset(bufnr, draft)
  nav_state[bufnr] = {
    index = #history + 1, -- Points past the end (current input position)
    draft = draft or {},
  }
end

---Navigate to previous history entry
---@param bufnr number Buffer number
---@return string[]|nil Lines to set in buffer, or nil if at oldest entry
function M.prev(bufnr)
  local state = nav_state[bufnr]
  if not state then
    -- Initialize state with current buffer content as draft
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    M.reset(bufnr, lines)
    state = nav_state[bufnr]
  end

  if #history == 0 then
    return nil
  end

  -- Save current content as draft if we're at the draft position
  if state.index > #history then
    state.draft = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end

  -- Move to previous entry
  if state.index > 1 then
    state.index = state.index - 1
    local content = history[state.index]
    return vim.split(content, "\n", { plain = true })
  end

  return nil
end

---Navigate to next history entry
---@param bufnr number Buffer number
---@return string[]|nil Lines to set in buffer, or nil if at newest entry
function M.next(bufnr)
  local state = nav_state[bufnr]
  if not state then
    return nil
  end

  -- Move to next entry
  if state.index <= #history then
    state.index = state.index + 1
    if state.index > #history then
      -- Return to draft
      return state.draft
    else
      local content = history[state.index]
      return vim.split(content, "\n", { plain = true })
    end
  end

  return nil
end

---Clear navigation state for a buffer (call after submit)
---@param bufnr number Buffer number
function M.clear_state(bufnr)
  nav_state[bufnr] = nil
end

---Get current navigation index for a buffer
---@param bufnr number Buffer number
---@return number|nil Current index, or nil if no state
function M.get_index(bufnr)
  local state = nav_state[bufnr]
  return state and state.index
end

return M
