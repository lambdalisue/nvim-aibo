local M = {}

---@alias GeminiDiffLocation { filepath: string, lnum: integer }

-- Box-drawing characters used by Ink's "round" borderStyle
local BOX_CHARS = "[│╭╮╰╯─]"

---Extract file path from a Gemini CLI tool header line.
---Gemini CLI renders tool output inside Ink bordered boxes. The header
---contains the tool name and description, e.g.:
---  "╭ ✓ WriteFile Writing to src/app.ts ─╮"
---  "│ ✓ WriteFile Writing to src/app.ts  │"
---  "│ ✓ Replace Replacing in src/app.ts  │"
---@param line string
---@return string? filepath Relative file path, or nil if not a header
local function parse_header_filepath(line)
  -- Strip box-drawing characters and normalize whitespace for flexible matching
  local stripped = line:gsub(BOX_CHARS, " ")

  -- WriteFile: "Writing to <path>"
  local path = stripped:match("Writing%s+to%s+(%S+)")
  if path then
    return path
  end

  -- Replace: "Replacing in <path>"
  path = stripped:match("Replacing%s+in%s+(%S+)")
  if path then
    return path
  end

  return nil
end

---Extract line number from a Gemini CLI diff content line.
---Content lines are inside an Ink bordered box with │ on left and right.
---Format: "│  7   context line                │"
---        "│  8  -deleted line                 │"
---        "│  9  +added line                   │"
---@param line string
---@return integer? lnum Line number, or nil if not a diff content line
local function parse_line_number(line)
  -- Content lines must be inside a bordered box
  if not line:find("│", 1, true) then
    return nil
  end

  -- Strip box-drawing border characters
  local content = line:gsub(BOX_CHARS, " ")

  -- Added/deleted lines: number followed by + or -
  local num = content:match("^%s*(%d+)%s+[%+%-]")
  if num then
    return tonumber(num)
  end

  -- Context lines: number followed by spaces then content
  -- The gutter padding + space sign + space after sign = at least 3 spaces
  num = content:match("^%s*(%d+)%s%s%s+%S")
  if num then
    return tonumber(num)
  end

  -- Empty content line inside border
  num = content:match("^%s*(%d+)%s*$")
  if num then
    return tonumber(num)
  end

  return nil
end

---Parse Gemini CLI diff output at a specific line to construct a file location.
---Extracts the line number from the given row and searches upward for the
---tool header to determine the file path.
---
---@param lines string[] Lines to search through (1-indexed)
---@param row integer 1-indexed row number within the lines array
---@param max_search? integer Maximum lines to search upward (default: 500)
---@return GeminiDiffLocation?
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

  -- Search upward for the tool header
  local start = math.max(1, row - max_search)
  for i = row - 1, start, -1 do
    local filepath = parse_header_filepath(lines[i])
    if filepath then
      return { filepath = filepath, lnum = lnum }
    end
  end

  return nil
end

---Parse Gemini CLI diff location at the cursor position in the given buffer.
---@param bufnr? integer Buffer number (default: current buffer)
---@param row? integer 1-indexed row (default: cursor row in current window)
---@return GeminiDiffLocation?
function M.get_cursor_diff_location(bufnr, row)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  row = row or vim.api.nvim_win_get_cursor(0)[1]

  local max_search = 500
  local start = math.max(0, row - max_search - 1)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start, row, false)

  return M.parse_diff_location(lines, #lines, max_search)
end

return M
