--- Completion module for @file path references in aibo prompt
--- Provides omnifunc-compatible completion for "@" file paths
---
--- Supported patterns:
---   @         -> list files from cwd
---   @src      -> filter files in cwd starting with "src"
---   @src/     -> list files inside "src" directory
---   @src/ma   -> filter files in "src" starting with "ma"
---   @/        -> list files from filesystem root
---   @/usr/bin -> filter files in "/usr" starting with "bin"
local M = {}

---Check if the cursor is at a position where @ file completion should trigger
---@param line string Current line content
---@param col number Cursor column (1-indexed)
---@return number|nil Start column of the "@" sign (1-indexed), or nil if not applicable
function M.find_at_start(line, col)
  local before_cursor = line:sub(1, col - 1)

  -- Walk backwards from cursor to find "@"
  local at_pos = nil
  for i = #before_cursor, 1, -1 do
    local char = before_cursor:sub(i, i)
    if char == "@" then
      -- "@" must be at start of line or preceded by whitespace
      if i == 1 or before_cursor:sub(i - 1, i - 1):match("%s") then
        at_pos = i
        break
      end
      -- "@" preceded by non-whitespace: not a valid trigger
      return nil
    elseif char:match("%s") then
      -- Hit whitespace before finding "@": no match
      break
    end
  end

  return at_pos
end

---Parse a @-prefixed path into root directory and filter prefix
---@param base string The text starting with "@" (e.g. "@src/main")
---@return string root The root directory for listing (absolute path)
---@return string dir The subdirectory portion (relative to root, no trailing /)
---@return string prefix The partial filename to filter by
local function parse_at_path(base)
  -- Strip leading "@"
  local path = base:sub(2)

  local root
  if path:sub(1, 1) == "/" then
    -- Absolute path: @/usr/bin/py -> root="/", rest="usr/bin/py"
    root = "/"
    path = path:sub(2)
  else
    -- Relative path: @src/main -> root=cwd, rest="src/main"
    root = vim.fn.getcwd()
  end

  -- Split into directory and prefix at the last "/"
  local last_slash = path:match(".*()/")
  local dir, prefix
  if last_slash then
    dir = path:sub(1, last_slash - 1)
    prefix = path:sub(last_slash + 1)
  else
    dir = ""
    prefix = path
  end

  return root, dir, prefix
end

---List directory entries and return completion items
---@param root string Root directory (absolute path)
---@param dir string Subdirectory relative to root
---@param prefix string Partial filename to filter by
---@param at_prefix string The "@" prefix portion for building word (e.g. "@", "@src/", "@/usr/")
---@return table[] List of completion items
local function list_completions(root, dir, prefix, at_prefix)
  local target_dir
  if dir == "" then
    target_dir = root
  else
    target_dir = root .. "/" .. dir
  end
  -- Normalize double slashes for root="/"
  target_dir = target_dir:gsub("//+", "/")

  if vim.fn.isdirectory(target_dir) ~= 1 then
    return {}
  end

  local ok, entries = pcall(vim.fn.readdir, target_dir)
  if not ok then
    return {}
  end
  local completions = {}
  local prefix_lower = prefix:lower()
  local max_entries = 500

  for _, name in ipairs(entries) do
    -- Skip hidden files (starting with ".")
    if name:sub(1, 1) ~= "." then
      if prefix == "" or name:sub(1, #prefix):lower() == prefix_lower then
        local full_path = target_dir .. "/" .. name
        local is_dir = vim.fn.isdirectory(full_path) == 1
        table.insert(completions, {
          word = at_prefix .. name,
          abbr = is_dir and (at_prefix .. name .. "/") or nil,
          kind = is_dir and "Dir" or "File",
          menu = is_dir and "[Dir]" or "[File]",
        })
        if #completions >= max_entries then
          break
        end
      end
    end
  end

  -- Sort: directories first, then alphabetical
  table.sort(completions, function(a, b)
    if a.kind ~= b.kind then
      return a.kind == "Dir"
    end
    return a.word:lower() < b.word:lower()
  end)

  return completions
end

---Get file path completions for a given @-prefixed base string
---@param base string The text starting with "@" (e.g. "@", "@src", "@src/ma", "@/usr/")
---@return table[] List of completion items with word, kind, and menu fields
function M.get_completions(base)
  if base:sub(1, 1) ~= "@" then
    return {}
  end

  local root, dir, prefix = parse_at_path(base)

  -- Build the at_prefix: everything before the prefix portion
  -- e.g. "@src/ma" -> at_prefix="@src/", prefix="ma"
  -- e.g. "@" -> at_prefix="@", prefix=""
  -- e.g. "@/" -> at_prefix="@/", prefix=""
  local at_prefix
  local path_after_at = base:sub(2)
  local last_slash = path_after_at:match(".*()/")
  if last_slash then
    at_prefix = "@" .. path_after_at:sub(1, last_slash)
  else
    at_prefix = "@"
  end

  return list_completions(root, dir, prefix, at_prefix)
end

---Determine how "/" key should behave in the context of @ file path completion.
---Used by ftplugin keymaps to decide whether to insert "/", skip it, or ignore.
---@param line string Current line content
---@param col number Cursor column (1-indexed, before "/" is typed)
---@return "trigger"|"insert_and_trigger"|nil
---  - "trigger": cursor is already after "/" in an @ path; re-trigger without inserting
---  - "insert_and_trigger": typing "/" extends an @ path; insert and re-trigger
---  - nil: not in an @ path context; caller decides default behavior
function M.handle_slash_key(line, col)
  -- If cursor is right after "/" in an @ path, don't insert a duplicate "/"
  -- This happens when CompleteDone inserts "/" after a directory selection
  if line:sub(col - 1, col - 1) == "/" and M.find_at_start(line, col) then
    return "trigger"
  end
  -- Simulate "/" being inserted at cursor position to check context
  local new_line = line:sub(1, col - 1) .. "/" .. line:sub(col)
  if M.find_at_start(new_line, col + 1) then
    return "insert_and_trigger"
  end
  return nil
end

--- Compute the segment offset for the current cursor position in an @ path.
--- Returns the at_start position and the column where the current segment begins
--- (after the last "/" within the @ path, or right after "@").
---@param line string Current line content
---@param col number Cursor column (1-indexed)
---@return number|nil at_start Position of "@", or nil
---@return number|nil segment_offset Start of current segment, or nil
local function get_segment_offset(line, col)
  local at_start = M.find_at_start(line, col)
  if not at_start then
    return nil, nil
  end
  local at_path = line:sub(at_start, col - 1)
  local last_slash_pos = at_path:match(".*()/")
  if last_slash_pos then
    return at_start, at_start + last_slash_pos
  end
  return at_start, at_start + 1
end

--- Setup auto-completion lifecycle for @ file paths on a buffer.
--- Registers TextChangedI/P, CompleteDone, InsertLeave autocmds.
--- Returns a controller table with activate()/deactivate()/is_active()/show()
--- methods that keymaps can call to start/stop completion sessions.
---@param bufnr number
---@return { activate: fun(), deactivate: fun(), is_active: fun(): boolean, show: fun() }
function M.setup_auto_completion(bufnr)
  local at_completion_active = false
  local last_segment_offset = nil
  local completing_dir = false

  -- Check if the completed word still matches the text before cursor.
  -- Returns false when BS/C-h dismissed the popup (text changed before
  -- the deferred callback runs).
  local function completed_word_matches(word)
    if vim.fn.mode() ~= "i" then
      return false
    end
    local line = vim.api.nvim_get_current_line()
    local col = vim.fn.col(".")
    local before = line:sub(1, col - 1)
    return before:sub(-#word) == word
  end

  -- Use a per-buffer augroup to prevent duplicate autocmds when called again
  local group = vim.api.nvim_create_augroup("aibo_file_completion_" .. bufnr, { clear = true })

  -- Recompute completions for the current @path and show popup directly.
  local function show_at_completions()
    local line = vim.api.nvim_get_current_line()
    local col = vim.fn.col(".")
    local at_start = M.find_at_start(line, col)
    if not at_start then
      at_completion_active = false
      last_segment_offset = nil
      return
    end
    local base = line:sub(at_start, col - 1)
    local items = M.get_completions(base)
    local _, seg_offset = get_segment_offset(line, col)
    last_segment_offset = seg_offset
    if #items > 0 then
      vim.fn.complete(at_start, items)
    else
      at_completion_active = false
    end
  end

  -- TextChangedI: fires when text changes with popup NOT visible.
  -- Handles: initial trigger after "@", popup re-show after BS closed it.
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = group,
    buffer = bufnr,
    callback = function()
      if not at_completion_active then
        return
      end
      show_at_completions()
    end,
  })

  -- TextChangedP: fires when text changes with popup visible.
  -- Only re-compute items when the segment offset changes (user crossed
  -- a "/" boundary). Otherwise let Vim's native prefix filter work.
  vim.api.nvim_create_autocmd("TextChangedP", {
    group = group,
    buffer = bufnr,
    callback = function()
      if not at_completion_active then
        return
      end
      -- Don't interfere with popup navigation (C-n/C-p changes text to
      -- highlighted item's word, which also triggers TextChangedP)
      local info = vim.fn.complete_info({ "selected" })
      if info.selected ~= -1 then
        return
      end
      local line = vim.api.nvim_get_current_line()
      local col = vim.fn.col(".")
      local _, segment_offset = get_segment_offset(line, col)
      if not segment_offset then
        at_completion_active = false
        last_segment_offset = nil
        return
      end
      if segment_offset == last_segment_offset then
        return
      end
      -- Segment offset changed: recompute and replace popup items
      show_at_completions()
    end,
  })

  -- Re-trigger completion after selecting a directory.
  -- Directory items use cmp-path style (word without trailing "/"),
  -- so insert "/" and let TextChangedI show the next-level popup.
  --
  -- NOTE: vim.fn.complete() uses "eval" completion mode where BS/C-h
  -- closes the popup (unlike <C-x><C-o> which re-filters). When BS
  -- closes the popup, CompleteDone fires with v:completed_item set to
  -- the C-n highlighted item — even though the user didn't confirm it.
  -- We defer all side effects to vim.schedule and verify the completed
  -- word still matches the buffer text to distinguish real selections
  -- from BS-dismissed popups.
  -- Handle directory selection: insert "/" to drill down into subdirectory.
  local function on_dir_completed(word)
    completing_dir = true
    vim.schedule(function()
      completing_dir = false
      if not completed_word_matches(word) then
        return
      end
      local line = vim.api.nvim_get_current_line()
      local col = vim.fn.col(".")
      local before = line:sub(1, col - 1)
      if before:sub(-1) == "/" then
        return
      end
      at_completion_active = true
      last_segment_offset = nil
      -- Insert "/" only ("n" bypasses the "/" keymap).
      -- TextChangedI will call show_at_completions() automatically.
      local key = vim.api.nvim_replace_termcodes("/", true, false, true)
      vim.api.nvim_feedkeys(key, "n", false)
    end)
  end

  -- Handle file selection: deactivate completion after confirming.
  local function on_file_completed(word)
    vim.schedule(function()
      if not completed_word_matches(word) then
        -- BS/C-h dismissed the popup; TextChangedI will re-trigger.
        return
      end
      at_completion_active = false
    end)
  end

  vim.api.nvim_create_autocmd("CompleteDone", {
    group = group,
    buffer = bufnr,
    callback = function()
      if completing_dir then
        return
      end
      local completed = vim.v.completed_item
      if not completed or not completed.kind then
        -- Popup dismissed without selection (C-e, etc.): keep state
        return
      end
      if completed.kind == "Dir" then
        on_dir_completed(completed.word)
      else
        on_file_completed(completed.word)
      end
    end,
  })

  -- Deactivate @ completion when leaving insert mode
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    buffer = bufnr,
    callback = function()
      at_completion_active = false
      last_segment_offset = nil
    end,
  })

  return {
    activate = function()
      at_completion_active = true
      last_segment_offset = nil
    end,
    deactivate = function()
      at_completion_active = false
      last_segment_offset = nil
    end,
    is_active = function()
      return at_completion_active
    end,
    show = function()
      show_at_completions()
    end,
  }
end

---Omnifunc for standalone @ file path completion
---@param findstart number 1 to find start position, 0 to get completions
---@param base string The text to complete (only used when findstart is 0)
---@return number|table Start position or completion list
function M.omnifunc(findstart, base)
  if findstart == 1 then
    local line = vim.api.nvim_get_current_line()
    local col = vim.fn.col(".")
    local start = M.find_at_start(line, col)

    if start then
      return start - 1 -- Convert to 0-indexed for omnifunc
    end

    return -3
  else
    if base:sub(1, 1) ~= "@" then
      base = "@" .. base
    end
    return M.get_completions(base)
  end
end

return M
