local M = {}

---@alias ClaudeCodeDiffLocation { filepath: string, lnum: integer }

-- The ⏺ (U+23FA) marker that Claude Code uses to prefix diff headers
local HEADER_MARKER = "⏺"

---Extract file path from a Claude Code diff header line.
---Header format: "⏺ Update(renderer/src/foo.ts)" or "⏺ Create(path/to/file)"
---@param line string
---@return string? filepath Relative file path, or nil if not a header
local function parse_header_filepath(line)
  if not line:find(HEADER_MARKER, 1, true) then
    return nil
  end
  return line:match("%w+%((.-)%)")
end

---Extract line number from a Claude Code diff content line.
---Content format: "      321 +code..." or "      315  code..." or "      316  "
---@param line string
---@return integer? lnum Line number, or nil if not a diff content line
local function parse_line_number(line)
  -- Leading whitespace, digits, then space followed by +/- or another space
  local num = line:match("^%s*(%d+)%s[%+%- ]")
  if num then
    return tonumber(num)
  end
  -- Lines where the content is empty (just number + trailing whitespace)
  num = line:match("^%s*(%d+)%s*$")
  if num then
    return tonumber(num)
  end
  return nil
end

---Parse Claude Code diff output at a specific line to construct a file location.
---Extracts the line number from the given row and searches upward for the
---diff header to determine the file path.
---
---@param lines string[] Lines to search through (1-indexed)
---@param row integer 1-indexed row number within the lines array
---@param max_search? integer Maximum lines to search upward (default: 500)
---@return ClaudeCodeDiffLocation?
---
---@usage
---   local cc = require("aibo.internal.claude_code")
---   local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
---   local loc = cc.parse_diff_location(lines, cursor_row)
---   if loc then
---     vim.cmd.edit(loc.filepath)
---     vim.api.nvim_win_set_cursor(0, { loc.lnum, 0 })
---   end
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

---Parse Claude Code diff location at the cursor position in the given buffer.
---Only reads from (cursor - max_search) to cursor to avoid loading entire
---terminal buffers which can be very large.
---
---@param bufnr? integer Buffer number (default: current buffer)
---@param row? integer 1-indexed row (default: cursor row in current window)
---@return ClaudeCodeDiffLocation?
function M.get_cursor_diff_location(bufnr, row)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  row = row or vim.api.nvim_win_get_cursor(0)[1]

  local max_search = 500
  local start = math.max(0, row - max_search - 1)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start, row, false)

  return M.parse_diff_location(lines, #lines, max_search)
end

return M
