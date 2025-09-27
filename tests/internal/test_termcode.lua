-- Tests for termcode module (lua/aibo/termcode.lua)

local T = require("mini.test")

-- Test set
local test_set = T.new_set({
  hooks = {
    post_case = function()
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

-- Test basic key resolution
test_set["resolves basic navigation keys"] = function()
  local termcode = require("aibo.termcode")

  -- Arrow keys
  T.expect.equality(termcode.resolve("<Up>"), "\27[A")
  T.expect.equality(termcode.resolve("<Down>"), "\27[B")
  T.expect.equality(termcode.resolve("<Left>"), "\27[D")
  T.expect.equality(termcode.resolve("<Right>"), "\27[C")

  -- Home/End
  T.expect.equality(termcode.resolve("<Home>"), "\27[H")
  T.expect.equality(termcode.resolve("<End>"), "\27[F")

  -- Page keys
  T.expect.equality(termcode.resolve("<PageUp>"), "\27[5~")
  T.expect.equality(termcode.resolve("<PageDown>"), "\27[6~")
end

-- Test control characters
test_set["resolves control characters"] = function()
  local termcode = require("aibo.termcode")

  T.expect.equality(termcode.resolve("<CR>"), "\13")
  T.expect.equality(termcode.resolve("<Enter>"), "\13")
  T.expect.equality(termcode.resolve("<Tab>"), "\9")
  T.expect.equality(termcode.resolve("<Esc>"), "\27")
  T.expect.equality(termcode.resolve("<Space>"), " ")
  T.expect.equality(termcode.resolve("<BS>"), "\127")
end

-- Test Ctrl combinations
test_set["resolves Ctrl+letter combinations"] = function()
  local termcode = require("aibo.termcode")

  -- Ctrl+A through Ctrl+Z
  T.expect.equality(termcode.resolve("<C-A>"), "\1")
  T.expect.equality(termcode.resolve("<C-B>"), "\2")
  T.expect.equality(termcode.resolve("<C-C>"), "\3")
  T.expect.equality(termcode.resolve("<C-L>"), "\12")
  T.expect.equality(termcode.resolve("<C-Z>"), "\26")

  -- Case insensitive
  T.expect.equality(termcode.resolve("<C-a>"), "\1")
end

-- Test modified keys
test_set["resolves modified navigation keys"] = function()
  local termcode = require("aibo.termcode")

  -- Shift combinations
  T.expect.equality(termcode.resolve("<S-Up>"), "\27[1;2A")
  T.expect.equality(termcode.resolve("<S-Down>"), "\27[1;2B")

  -- Ctrl combinations
  T.expect.equality(termcode.resolve("<C-Up>"), "\27[1;5A")
  T.expect.equality(termcode.resolve("<C-Left>"), "\27[1;5D")
  T.expect.equality(termcode.resolve("<C-Right>"), "\27[1;5C")

  -- Alt combinations
  T.expect.equality(termcode.resolve("<A-Up>"), "\27[1;3A")
  T.expect.equality(termcode.resolve("<M-Up>"), "\27[1;3A") -- Meta = Alt

  -- Combined modifiers
  T.expect.equality(termcode.resolve("<C-S-Up>"), "\27[1;6A")
  T.expect.equality(termcode.resolve("<C-A-Up>"), "\27[1;7A")
end

-- Test function keys
test_set["resolves function keys"] = function()
  local termcode = require("aibo.termcode")

  -- Basic function keys
  T.expect.equality(termcode.resolve("<F1>"), "\27OP")
  T.expect.equality(termcode.resolve("<F2>"), "\27OQ")
  T.expect.equality(termcode.resolve("<F3>"), "\27OR")
  T.expect.equality(termcode.resolve("<F4>"), "\27OS")
  T.expect.equality(termcode.resolve("<F5>"), "\27[15~")
  T.expect.equality(termcode.resolve("<F12>"), "\27[24~")

  -- Modified function keys (F1-F4 change format with modifiers)
  T.expect.equality(termcode.resolve("<C-F1>"), "\27[1;5P")
  T.expect.equality(termcode.resolve("<S-F1>"), "\27[1;2P")
  T.expect.equality(termcode.resolve("<C-F4>"), "\27[1;5S")

  -- Modified function keys (F5-F12 use parameter format)
  T.expect.equality(termcode.resolve("<S-F5>"), "\27[15;2~")
  T.expect.equality(termcode.resolve("<C-F5>"), "\27[15;5~")
  T.expect.equality(termcode.resolve("<C-F12>"), "\27[24;5~")
end

-- Test multiple keys
test_set["resolves multiple key sequences"] = function()
  local termcode = require("aibo.termcode")

  T.expect.equality(termcode.resolve("<Up><Down>"), "\27[A\27[B")
  T.expect.equality(termcode.resolve("<C-A><C-B>"), "\1\2")
  T.expect.equality(termcode.resolve("abc<CR>"), "abc\13")
end

-- Test literal text
test_set["handles literal text"] = function()
  local termcode = require("aibo.termcode")

  T.expect.equality(termcode.resolve("hello"), "hello")
  T.expect.equality(termcode.resolve("123"), "123")
  T.expect.equality(termcode.resolve("hello<Space>world"), "hello world")
end

-- Test edge cases
test_set["handles edge cases"] = function()
  local termcode = require("aibo.termcode")

  -- Empty input
  T.expect.equality(termcode.resolve(""), nil)
  T.expect.equality(termcode.resolve(nil), nil)

  -- Unknown keys
  T.expect.equality(termcode.resolve("<Unknown>"), nil)
  T.expect.equality(termcode.resolve("<NotAKey>"), nil)

  -- Unclosed brackets
  T.expect.equality(termcode.resolve("<Up"), "<Up")
  T.expect.equality(termcode.resolve("text<"), "text<")

  -- Special characters in brackets
  T.expect.equality(termcode.resolve("<lt>"), "<")
  T.expect.equality(termcode.resolve("<gt>"), ">")
  T.expect.equality(termcode.resolve("<Bar>"), "|")
end

-- Test case sensitivity
test_set["handles case variations"] = function()
  local termcode = require("aibo.termcode")

  -- Keys are case-insensitive
  T.expect.equality(termcode.resolve("<up>"), "\27[A")
  T.expect.equality(termcode.resolve("<UP>"), "\27[A")
  T.expect.equality(termcode.resolve("<Up>"), "\27[A")

  -- Modifiers too
  T.expect.equality(termcode.resolve("<c-a>"), "\1")
  T.expect.equality(termcode.resolve("<C-a>"), "\1")
  T.expect.equality(termcode.resolve("<C-A>"), "\1")
end

return test_set
