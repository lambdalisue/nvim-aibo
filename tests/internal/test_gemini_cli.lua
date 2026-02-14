local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- WriteFile tool

T["parse_diff_location extracts from WriteFile header with top border"] = function()
  local gemini = require("aibo.internal.gemini_cli")
  local lines = {
    "╭ ✓ WriteFile Writing to src/app.ts ──────────╮",
    "│  10   const x = 1;                           │",
    "│  11  -const y = 2;                           │",
    "│  12  +const y = 3;                           │",
    "│  13   return x;                              │",
    "╰──────────────────────────────────────────────╯",
  }

  local loc = gemini.parse_diff_location(lines, 4) -- line 12
  eq(loc.filepath, "src/app.ts")
  eq(loc.lnum, 12)
end

T["parse_diff_location extracts from WriteFile header as regular line"] = function()
  local gemini = require("aibo.internal.gemini_cli")
  -- Alternative rendering where header is inside the box, not in the border
  local lines = {
    "╭──────────────────────────────────────────────╮",
    "│ ✓ WriteFile Writing to src/app.ts            │",
    "│  10   const x = 1;                           │",
    "│  11  +const y = 2;                           │",
    "╰──────────────────────────────────────────────╯",
  }

  local loc = gemini.parse_diff_location(lines, 4)
  eq(loc.filepath, "src/app.ts")
  eq(loc.lnum, 11)
end

T["parse_diff_location extracts from unchanged line"] = function()
  local gemini = require("aibo.internal.gemini_cli")
  local lines = {
    "╭ ✓ WriteFile Writing to src/app.ts ──────────╮",
    "│  10   const x = 1;                           │",
    "│  11  +added line                             │",
    "╰──────────────────────────────────────────────╯",
  }

  local loc = gemini.parse_diff_location(lines, 2) -- unchanged line 10
  eq(loc.filepath, "src/app.ts")
  eq(loc.lnum, 10)
end

-- Replace tool

T["parse_diff_location works with Replace header"] = function()
  local gemini = require("aibo.internal.gemini_cli")
  local lines = {
    "╭ ✓ Replace Replacing in src/utils.ts ────────╮",
    "│   5   function foo() {                       │",
    "│   6  -  return null;                         │",
    "│   7  +  return 42;                           │",
    "│   8   }                                      │",
    "╰──────────────────────────────────────────────╯",
  }

  local loc = gemini.parse_diff_location(lines, 4) -- line 7
  eq(loc.filepath, "src/utils.ts")
  eq(loc.lnum, 7)
end

-- New file (all added lines)

T["parse_diff_location works with new file"] = function()
  local gemini = require("aibo.internal.gemini_cli")
  local lines = {
    "╭ ✓ WriteFile Writing to src/new.ts ──────────╮",
    "│   1  +import { foo } from 'bar';             │",
    "│   2  +                                       │",
    "│   3  +export const x = 1;                    │",
    "╰──────────────────────────────────────────────╯",
  }

  local loc = gemini.parse_diff_location(lines, 4) -- line 3
  eq(loc.filepath, "src/new.ts")
  eq(loc.lnum, 3)
end

-- Gap indicator

T["parse_diff_location works across gap indicator"] = function()
  local gemini = require("aibo.internal.gemini_cli")
  local lines = {
    "╭ ✓ WriteFile Writing to src/app.ts ──────────╮",
    "│   5   line five                              │",
    "│ ═══════════════════════════════════════════   │",
    "│  50  +new line fifty                         │",
    "╰──────────────────────────────────────────────╯",
  }

  local loc = gemini.parse_diff_location(lines, 4)
  eq(loc.filepath, "src/app.ts")
  eq(loc.lnum, 50)
end

-- Multiple tool calls

T["parse_diff_location finds nearest header with multiple tool blocks"] = function()
  local gemini = require("aibo.internal.gemini_cli")
  local lines = {
    "╭ ✓ WriteFile Writing to src/first.ts ────────╮",
    "│   1  +first file content                     │",
    "╰──────────────────────────────────────────────╯",
    "",
    "╭ ✓ WriteFile Writing to src/second.ts ───────╮",
    "│  10  +second file content                    │",
    "╰──────────────────────────────────────────────╯",
  }

  -- Line in second block
  local loc = gemini.parse_diff_location(lines, 6)
  eq(loc.filepath, "src/second.ts")
  eq(loc.lnum, 10)

  -- Line in first block
  local loc2 = gemini.parse_diff_location(lines, 2)
  eq(loc2.filepath, "src/first.ts")
  eq(loc2.lnum, 1)
end

-- Edge cases

T["parse_diff_location returns nil for line outside border"] = function()
  local gemini = require("aibo.internal.gemini_cli")
  local lines = {
    "╭ ✓ WriteFile Writing to src/app.ts ──────────╮",
    "│   1  +code                                   │",
    "╰──────────────────────────────────────────────╯",
    "some text outside the box with number 42",
  }

  -- Line 4 is outside the border, should not match
  eq(gemini.parse_diff_location(lines, 4), nil)
end

T["parse_diff_location returns nil for border-only line"] = function()
  local gemini = require("aibo.internal.gemini_cli")
  local lines = {
    "╭ ✓ WriteFile Writing to src/app.ts ──────────╮",
    "╰──────────────────────────────────────────────╯",
  }

  eq(gemini.parse_diff_location(lines, 2), nil)
end

T["parse_diff_location returns nil when no header found"] = function()
  local gemini = require("aibo.internal.gemini_cli")
  local lines = {
    "│   1  +orphan line inside border              │",
  }

  eq(gemini.parse_diff_location(lines, 1), nil)
end

T["parse_diff_location handles deeply nested paths"] = function()
  local gemini = require("aibo.internal.gemini_cli")
  local lines = {
    "╭ ✓ WriteFile Writing to packages/core/src/utils/helpers.ts ─╮",
    "│  42  +export function foo() {}                              │",
    "╰─────────────────────────────────────────────────────────────╯",
  }

  local loc = gemini.parse_diff_location(lines, 2)
  eq(loc.filepath, "packages/core/src/utils/helpers.ts")
  eq(loc.lnum, 42)
end

return T
