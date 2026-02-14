local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- ============================================================================
-- find_at_start tests
-- ============================================================================

T["find_at_start"] = MiniTest.new_set()

T["find_at_start"]["returns position when @ is at start of line"] = function()
  local file = require("aibo.completion.file")
  -- "@" at col=1, cursor at col=2 (after @)
  eq(file.find_at_start("@", 2), 1)
end

T["find_at_start"]["returns position when @ is at start with trailing text"] = function()
  local file = require("aibo.completion.file")
  -- "@src" cursor at col=5
  eq(file.find_at_start("@src", 5), 1)
end

T["find_at_start"]["returns position when @ follows whitespace"] = function()
  local file = require("aibo.completion.file")
  -- "hello @src" cursor at col=11
  eq(file.find_at_start("hello @src", 11), 7)
end

T["find_at_start"]["returns nil when @ is inside a word"] = function()
  local file = require("aibo.completion.file")
  -- "user@host" cursor at col=10
  eq(file.find_at_start("user@host", 10), nil)
end

T["find_at_start"]["returns nil when no @ in line"] = function()
  local file = require("aibo.completion.file")
  eq(file.find_at_start("hello world", 12), nil)
end

T["find_at_start"]["returns nil for empty line"] = function()
  local file = require("aibo.completion.file")
  eq(file.find_at_start("", 1), nil)
end

T["find_at_start"]["handles @ with path separators"] = function()
  local file = require("aibo.completion.file")
  -- "@src/main" cursor at col=10
  eq(file.find_at_start("@src/main", 10), 1)
end

T["find_at_start"]["handles @/ for absolute path"] = function()
  local file = require("aibo.completion.file")
  -- "@/" cursor at col=3
  eq(file.find_at_start("@/", 3), 1)
end

T["find_at_start"]["handles @ after tab character"] = function()
  local file = require("aibo.completion.file")
  -- "\t@src" cursor at col=6
  eq(file.find_at_start("\t@src", 6), 2)
end

-- ============================================================================
-- handle_slash_key tests
-- ============================================================================

T["handle_slash_key"] = MiniTest.new_set()

T["handle_slash_key"]["returns insert_and_trigger when / extends an @ path"] = function()
  local file = require("aibo.completion.file")
  -- "@src" cursor at col=5 (after "src"), user types "/"
  eq(file.handle_slash_key("@src", 5), "insert_and_trigger")
end

T["handle_slash_key"]["returns trigger when cursor is right after / in @ path"] = function()
  local file = require("aibo.completion.file")
  -- "@src/" cursor at col=6 (after "/"), user types "/" again
  eq(file.handle_slash_key("@src/", 6), "trigger")
end

T["handle_slash_key"]["returns nil when not in @ context"] = function()
  local file = require("aibo.completion.file")
  -- "hello" cursor at col=6, no @ prefix
  eq(file.handle_slash_key("hello", 6), nil)
end

T["handle_slash_key"]["returns nil for empty line"] = function()
  local file = require("aibo.completion.file")
  eq(file.handle_slash_key("", 1), nil)
end

T["handle_slash_key"]["returns insert_and_trigger for @/ absolute path"] = function()
  local file = require("aibo.completion.file")
  -- "@" cursor at col=2, user types "/" to start absolute path
  eq(file.handle_slash_key("@", 2), "insert_and_trigger")
end

T["handle_slash_key"]["returns trigger for @/ when / already present"] = function()
  local file = require("aibo.completion.file")
  -- "@/" cursor at col=3, user types "/" again
  eq(file.handle_slash_key("@/", 3), "trigger")
end

T["handle_slash_key"]["returns nil for / not in @ context"] = function()
  local file = require("aibo.completion.file")
  -- "path/" cursor at col=6
  eq(file.handle_slash_key("path/", 6), nil)
end

-- ============================================================================
-- get_completions tests
-- ============================================================================

T["get_completions"] = MiniTest.new_set()

T["get_completions"]["returns empty table for non-@ input"] = function()
  local file = require("aibo.completion.file")
  eq(file.get_completions("src"), {})
end

T["get_completions"]["returns entries for @ (cwd listing)"] = function()
  local file = require("aibo.completion.file")
  local completions = file.get_completions("@")
  eq(type(completions), "table")
  eq(#completions > 0, true)

  -- All words should start with "@"
  for _, item in ipairs(completions) do
    eq(item.word:sub(1, 1), "@")
  end
end

T["get_completions"]["directory word does not end with /"] = function()
  local file = require("aibo.completion.file")
  local completions = file.get_completions("@")

  local found_dir = false
  for _, item in ipairs(completions) do
    if item.kind == "Dir" then
      found_dir = true
      -- word should NOT have trailing "/" (cmp-path style)
      eq(item.word:sub(-1) ~= "/", true)
      -- abbr should have trailing "/" for display
      eq(item.abbr:sub(-1), "/")
    end
  end
  -- Project root should have at least one directory (lua/, tests/, etc.)
  eq(found_dir, true)
end

T["get_completions"]["file entries do not end with /"] = function()
  local file = require("aibo.completion.file")
  local completions = file.get_completions("@")

  for _, item in ipairs(completions) do
    if item.kind == "File" then
      eq(item.word:sub(-1) ~= "/", true)
    end
  end
end

T["get_completions"]["filters by prefix"] = function()
  local file = require("aibo.completion.file")
  -- "lua" directory should exist in project root
  local completions = file.get_completions("@lu")
  eq(type(completions), "table")

  for _, item in ipairs(completions) do
    -- After "@", the name should start with "lu"
    local name = item.word:sub(2):gsub("/$", "")
    eq(name:sub(1, 2):lower(), "lu")
  end
end

T["get_completions"]["lists subdirectory contents"] = function()
  local file = require("aibo.completion.file")
  -- "lua/" directory should have "aibo" subdirectory
  local completions = file.get_completions("@lua/")
  eq(type(completions), "table")
  eq(#completions > 0, true)

  -- All words should start with "@lua/"
  for _, item in ipairs(completions) do
    eq(item.word:sub(1, 5), "@lua/")
  end
end

T["get_completions"]["filters subdirectory contents by prefix"] = function()
  local file = require("aibo.completion.file")
  local completions = file.get_completions("@lua/ai")
  eq(type(completions), "table")
  eq(#completions > 0, true)

  -- Should find "aibo" directory (word without trailing "/")
  local found = false
  for _, item in ipairs(completions) do
    if item.word == "@lua/aibo" then
      found = true
      eq(item.kind, "Dir")
      eq(item.abbr, "@lua/aibo/")
    end
  end
  eq(found, true)
end

T["get_completions"]["handles absolute path with @/"] = function()
  local file = require("aibo.completion.file")
  local completions = file.get_completions("@/")
  eq(type(completions), "table")
  -- Root filesystem should have entries
  eq(#completions > 0, true)

  -- All words should start with "@/"
  for _, item in ipairs(completions) do
    eq(item.word:sub(1, 2), "@/")
  end
end

T["get_completions"]["returns empty table for non-existent directory"] = function()
  local file = require("aibo.completion.file")
  local completions = file.get_completions("@nonexistent_dir_xyz/")
  eq(type(completions), "table")
  eq(#completions, 0)
end

T["get_completions"]["directories sorted before files"] = function()
  local file = require("aibo.completion.file")
  local completions = file.get_completions("@")

  -- Find first file and last directory positions
  local last_dir_idx = 0
  local first_file_idx = #completions + 1
  for i, item in ipairs(completions) do
    if item.kind == "Dir" then
      last_dir_idx = i
    elseif item.kind == "File" and i < first_file_idx then
      first_file_idx = i
    end
  end

  -- All directories should come before all files
  if last_dir_idx > 0 and first_file_idx <= #completions then
    eq(last_dir_idx < first_file_idx, true)
  end
end

T["get_completions"]["items have correct structure"] = function()
  local file = require("aibo.completion.file")
  local completions = file.get_completions("@")

  for _, item in ipairs(completions) do
    eq(type(item.word), "string")
    eq(item.kind == "Dir" or item.kind == "File", true)
    eq(type(item.menu), "string")
    if item.kind == "Dir" then
      -- Directories have abbr with trailing "/"
      eq(type(item.abbr), "string")
      eq(item.abbr, item.word .. "/")
    else
      -- Files have no abbr
      eq(item.abbr, nil)
    end
  end
end

T["get_completions"]["skips hidden files"] = function()
  local file = require("aibo.completion.file")
  local completions = file.get_completions("@")

  for _, item in ipairs(completions) do
    -- The second character (after @) should not be "."
    local name_start = item.word:sub(2, 2)
    eq(name_start ~= ".", true)
  end
end

-- ============================================================================
-- omnifunc tests
-- ============================================================================

T["omnifunc"] = MiniTest.new_set()

T["omnifunc"]["findstart returns correct position"] = function()
  local file = require("aibo.completion.file")

  -- Set up buffer with "@src" text
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "@src" })
  vim.fn.cursor(1, 5) -- After "src"

  local start = file.omnifunc(1, "")
  eq(start, 0) -- 0-indexed position of "@"
end

T["omnifunc"]["findstart returns -3 when no @ trigger"] = function()
  local file = require("aibo.completion.file")

  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello world" })
  vim.fn.cursor(1, 12)

  local start = file.omnifunc(1, "")
  eq(start, -3)
end

T["omnifunc"]["completion returns items for @ base"] = function()
  local file = require("aibo.completion.file")

  local completions = file.omnifunc(0, "@")
  eq(type(completions), "table")
  eq(#completions > 0, true)
end

T["omnifunc"]["completion prepends @ if missing from base"] = function()
  local file = require("aibo.completion.file")

  -- omnifunc should handle base without "@" prefix
  local completions = file.omnifunc(0, "lu")
  eq(type(completions), "table")

  for _, item in ipairs(completions) do
    eq(item.word:sub(1, 1), "@")
  end
end

-- ============================================================================
-- setup_auto_completion tests
-- ============================================================================

T["setup_auto_completion"] = MiniTest.new_set()

T["setup_auto_completion"]["returns controller with expected methods"] = function()
  local file = require("aibo.completion.file")
  local controller = file.setup_auto_completion(0)

  eq(type(controller), "table")
  eq(type(controller.activate), "function")
  eq(type(controller.deactivate), "function")
  eq(type(controller.is_active), "function")
  eq(type(controller.show), "function")
end

T["setup_auto_completion"]["is_active returns false initially"] = function()
  local file = require("aibo.completion.file")
  local controller = file.setup_auto_completion(0)

  eq(controller.is_active(), false)
end

T["setup_auto_completion"]["activate sets is_active to true"] = function()
  local file = require("aibo.completion.file")
  local controller = file.setup_auto_completion(0)

  controller.activate()
  eq(controller.is_active(), true)
end

T["setup_auto_completion"]["deactivate sets is_active to false"] = function()
  local file = require("aibo.completion.file")
  local controller = file.setup_auto_completion(0)

  controller.activate()
  eq(controller.is_active(), true)
  controller.deactivate()
  eq(controller.is_active(), false)
end

T["setup_auto_completion"]["multiple controllers are independent"] = function()
  local file = require("aibo.completion.file")
  local buf1 = vim.api.nvim_create_buf(false, true)
  local buf2 = vim.api.nvim_create_buf(false, true)
  local c1 = file.setup_auto_completion(buf1)
  local c2 = file.setup_auto_completion(buf2)

  c1.activate()
  eq(c1.is_active(), true)
  eq(c2.is_active(), false)

  c2.activate()
  c1.deactivate()
  eq(c1.is_active(), false)
  eq(c2.is_active(), true)
end

return T
