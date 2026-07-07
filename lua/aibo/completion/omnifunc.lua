--- Shared omnifunc factory for "/" slash-command + "@" file completion, used
--- by completion/{claude,codex,gemini}.lua. Each of those supplies its own
--- `get_commands` function (sourced from its own live probe); this module
--- owns the cursor-position detection, prefix filtering, and routing
--- between "/" and "@" completion that all three share.
local M = {}

local file_completion = require("aibo.completion.file")

---Check if the cursor is at a position where slash command completion should trigger
---@param line string Current line content
---@param col number Cursor column (1-indexed)
---@return number|nil Start column of the slash command, or nil if not applicable
local function find_slash_start(line, col)
  local before_cursor = line:sub(1, col - 1)

  -- Find "/" at start of line or after whitespace
  local slash_pos = nil
  for i = #before_cursor, 1, -1 do
    local char = before_cursor:sub(i, i)
    if char == "/" then
      if i == 1 or before_cursor:sub(i - 1, i - 1):match("%s") then
        slash_pos = i
        break
      end
    elseif char:match("%s") then
      break
    end
  end

  return slash_pos
end

---Build an omnifunc that sources "/" completions from `get_commands()` and
---routes "@" completions to the shared file-completion module.
---@param get_commands fun(): table[]
---@return fun(findstart: number, base: string): number|table omnifunc
function M.make(get_commands)
  local function get_slash_completions(base)
    local completions = {}
    local prefix = base:lower()

    for _, item in ipairs(get_commands()) do
      if item.cmd:lower():find(prefix, 1, true) == 1 then
        table.insert(completions, {
          word = item.cmd,
          menu = item.description,
          kind = "Slash",
        })
      end
    end

    return completions
  end

  ---@param findstart number 1 to find start position, 0 to get completions
  ---@param base string The text to complete (only used when findstart is 0)
  ---@return number|table Start position or completion list
  return function(findstart, base)
    if findstart == 1 then
      local line = vim.api.nvim_get_current_line()
      local col = vim.fn.col(".")

      -- Check @ file completion first (since @/ contains "/" which could match slash)
      local at_start = file_completion.find_at_start(line, col)
      if at_start then
        return at_start - 1 -- Convert to 0-indexed
      end

      -- Then check / slash command completion
      local slash_start = find_slash_start(line, col)
      if slash_start then
        return slash_start - 1 -- Convert to 0-indexed
      end

      return -3
    else
      -- Route to appropriate completion based on trigger character
      if base:sub(1, 1) == "@" then
        return file_completion.get_completions(base)
      end

      if base:sub(1, 1) ~= "/" then
        base = "/" .. base
      end
      return get_slash_completions(base)
    end
  end
end

return M
