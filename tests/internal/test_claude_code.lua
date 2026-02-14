local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Helper to build diff output lines for tests
local function make_update_diff()
  return {
    "⏺ Update(renderer/src/context-menu-handler.ts)",
    "  ⎿  Added 52 lines",
    "      315  }",
    "      316  ",
    "      317  /**",
    "      318 + * Detect if the right-click target is inside a table element.",
    "      319 + * Returns table data (CSV/TSV) and source line range, or null if not in a table.",
    "      320 + */",
    "      321 +function detectTable(target: HTMLElement): TableData | null {",
    '      322 +  const table = target.closest("table") as HTMLTableElement | null;',
    "      323 +  if (!table) return null;",
  }
end

-- parse_diff_location: basic extraction

T["parse_diff_location extracts filepath and lnum from added line"] = function()
  local cc = require("aibo.internal.claude_code")
  local lines = make_update_diff()

  local loc = cc.parse_diff_location(lines, 9) -- "321 +function ..."
  eq(loc.filepath, "renderer/src/context-menu-handler.ts")
  eq(loc.lnum, 321)
end

T["parse_diff_location extracts from unchanged line"] = function()
  local cc = require("aibo.internal.claude_code")
  local lines = make_update_diff()

  local loc = cc.parse_diff_location(lines, 3) -- "315  }"
  eq(loc.filepath, "renderer/src/context-menu-handler.ts")
  eq(loc.lnum, 315)
end

T["parse_diff_location extracts from blank content line"] = function()
  local cc = require("aibo.internal.claude_code")
  local lines = make_update_diff()

  local loc = cc.parse_diff_location(lines, 4) -- "316  " (empty content)
  eq(loc.filepath, "renderer/src/context-menu-handler.ts")
  eq(loc.lnum, 316)
end

-- parse_diff_location: different operations

T["parse_diff_location works with Create header"] = function()
  local cc = require("aibo.internal.claude_code")
  local lines = {
    "⏺ Create(src/new-file.ts)",
    "      1 +import { foo } from 'bar';",
    "      2 +",
    "      3 +export function main() {",
  }

  local loc = cc.parse_diff_location(lines, 4)
  eq(loc.filepath, "src/new-file.ts")
  eq(loc.lnum, 3)
end

T["parse_diff_location works with Write header"] = function()
  local cc = require("aibo.internal.claude_code")
  local lines = {
    "⏺ Write(docs/README.md)",
    "      1 +# Title",
    "      2 +",
  }

  local loc = cc.parse_diff_location(lines, 2)
  eq(loc.filepath, "docs/README.md")
  eq(loc.lnum, 1)
end

-- parse_diff_location: deleted lines

T["parse_diff_location extracts from deleted line"] = function()
  local cc = require("aibo.internal.claude_code")
  local lines = {
    "⏺ Update(src/app.ts)",
    "  ⎿  Removed 2 lines",
    "      10  const x = 1;",
    "      11 -const y = 2;",
    "      12 -const z = 3;",
    "      13  return x;",
  }

  local loc = cc.parse_diff_location(lines, 4)
  eq(loc.filepath, "src/app.ts")
  eq(loc.lnum, 11)
end

-- parse_diff_location: multiple diff blocks

T["parse_diff_location finds nearest header when multiple blocks exist"] = function()
  local cc = require("aibo.internal.claude_code")
  local lines = {
    "⏺ Update(src/first.ts)",
    "      1  line one",
    "      2 +added line",
    "",
    "⏺ Update(src/second.ts)",
    "      10  line ten",
    "      11 +added line in second",
  }

  -- Line in second block should find second header
  local loc = cc.parse_diff_location(lines, 7)
  eq(loc.filepath, "src/second.ts")
  eq(loc.lnum, 11)

  -- Line in first block should find first header
  local loc2 = cc.parse_diff_location(lines, 3)
  eq(loc2.filepath, "src/first.ts")
  eq(loc2.lnum, 2)
end

-- parse_diff_location: edge cases

T["parse_diff_location returns nil for non-diff line"] = function()
  local cc = require("aibo.internal.claude_code")
  local lines = {
    "⏺ Update(src/app.ts)",
    "  ⎿  Added 1 line",
    "Some random text without line number",
  }

  eq(cc.parse_diff_location(lines, 3), nil)
end

T["parse_diff_location returns nil for header line itself"] = function()
  local cc = require("aibo.internal.claude_code")
  local lines = {
    "⏺ Update(src/app.ts)",
    "      1  code",
  }

  -- The header line doesn't have a line number, so returns nil
  eq(cc.parse_diff_location(lines, 1), nil)
end

T["parse_diff_location returns nil when no header found above"] = function()
  local cc = require("aibo.internal.claude_code")
  local lines = {
    "      1  orphan line with no header",
  }

  eq(cc.parse_diff_location(lines, 1), nil)
end

T["parse_diff_location returns nil for out-of-range row"] = function()
  local cc = require("aibo.internal.claude_code")
  local lines = { "⏺ Update(src/app.ts)" }

  eq(cc.parse_diff_location(lines, 99), nil)
end

T["parse_diff_location respects max_search limit"] = function()
  local cc = require("aibo.internal.claude_code")
  -- Build a large gap between header and content
  local lines = { "⏺ Update(src/app.ts)" }
  for i = 1, 10 do
    lines[#lines + 1] = string.format("      %d  filler", i)
  end

  -- With max_search=5, the header is too far above row 11
  eq(cc.parse_diff_location(lines, 11, 5), nil)

  -- With default max_search (500), it should find it
  local loc = cc.parse_diff_location(lines, 11)
  eq(loc.filepath, "src/app.ts")
  eq(loc.lnum, 10)
end

-- parse_diff_location: filepath edge cases

T["parse_diff_location handles deeply nested paths"] = function()
  local cc = require("aibo.internal.claude_code")
  local lines = {
    "⏺ Update(packages/core/src/utils/string-helpers.ts)",
    "      42 +export function trim(s: string) {",
  }

  local loc = cc.parse_diff_location(lines, 2)
  eq(loc.filepath, "packages/core/src/utils/string-helpers.ts")
  eq(loc.lnum, 42)
end

T["parse_diff_location handles paths with dots"] = function()
  local cc = require("aibo.internal.claude_code")
  local lines = {
    "⏺ Update(.github/workflows/ci.yml)",
    "      7 +  push:",
  }

  local loc = cc.parse_diff_location(lines, 2)
  eq(loc.filepath, ".github/workflows/ci.yml")
  eq(loc.lnum, 7)
end

return T
