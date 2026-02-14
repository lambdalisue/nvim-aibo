local M = {}

---@alias CodexDiffLocation { filepath: string, lnum: integer }

---Extract file path from a Codex CLI diff header line.
---Single-file header: "• Edited src/app.ts (+3 -1)"
---Multi-file sub-header: "  └ src/app.ts (+3 -1)"
---Verbs: Added, Deleted, Edited
---@param line string
---@return string? filepath Relative file path, or nil if not a header
local function parse_header_filepath(line)
  -- Single file: • <Verb> <path> (+N -M)
  -- The bullet • (U+2022) distinguishes Codex headers from other output
  local path = line:match("•%s+%w+%s+(.-)%s+%(%+%d")
  if path then
    -- Exclude multi-file summary like "• Edited 2 files (+5 -2)"
    if not path:match("^%d+%s+files?$") then
      return path
    end
  end

  -- Multi-file sub-header: └ <path> (+N -M)
  path = line:match("└%s+(.-)%s+%(%+%d")
  if path then
    return path
  end

  return nil
end

---Extract line number from a Codex CLI diff content line.
---Content lines are indented with 4 spaces, then right-aligned number + sign.
---Format: "     10 +code..." or "     10  code..." or "     10 -code..."
---@param line string
---@return integer? lnum Line number, or nil if not a diff content line
local function parse_line_number(line)
  -- Leading whitespace (at least 4 spaces indent), digits, then space + sign
  local num = line:match("^%s+(%d+)%s[%+%- ]")
  if num then
    return tonumber(num)
  end
  -- Empty content line (just number + trailing whitespace)
  num = line:match("^%s+(%d+)%s*$")
  if num then
    return tonumber(num)
  end
  return nil
end

---Parse Codex CLI diff output at a specific line to construct a file location.
---Extracts the line number from the given row and searches upward for the
---diff header to determine the file path.
---
---@param lines string[] Lines to search through (1-indexed)
---@param row integer 1-indexed row number within the lines array
---@param max_search? integer Maximum lines to search upward (default: 500)
---@return CodexDiffLocation?
function M.parse_diff_location(lines, row, max_search)
  max_search = max_search or 500

  local line = lines[row]
  if not line then
    return nil
  end

  local lnum = parse_line_number(line)
  if not lnum then
    return nil
  end

  -- Search upward for the diff header
  local start = math.max(1, row - max_search)
  for i = row - 1, start, -1 do
    local filepath = parse_header_filepath(lines[i])
    if filepath then
      return { filepath = filepath, lnum = lnum }
    end
  end

  return nil
end

---Parse Codex CLI diff location at the cursor position in the given buffer.
---@param bufnr? integer Buffer number (default: current buffer)
---@param row? integer 1-indexed row (default: cursor row in current window)
---@return CodexDiffLocation?
function M.get_cursor_diff_location(bufnr, row)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  row = row or vim.api.nvim_win_get_cursor(0)[1]

  local max_search = 500
  local start = math.max(0, row - max_search - 1)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start, row, false)

  return M.parse_diff_location(lines, #lines, max_search)
end

return M
