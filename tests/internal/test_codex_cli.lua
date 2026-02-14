local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Single-file edit

T["parse_diff_location extracts from single-file Edited header"] = function()
  local codex = require("aibo.internal.codex_cli")
  local lines = {
    "• Edited src/app.ts (+3 -1)",
    "     10  const x = 1;",
    "     11 -const y = 2;",
    "     12 +const y = 3;",
    "     13 +const z = 4;",
    "     14  return x;",
  }

  local loc = codex.parse_diff_location(lines, 4) -- line 12
  eq(loc.filepath, "src/app.ts")
  eq(loc.lnum, 12)
end

T["parse_diff_location extracts from unchanged line"] = function()
  local codex = require("aibo.internal.codex_cli")
  local lines = {
    "• Edited src/app.ts (+1 -0)",
    "     10  const x = 1;",
    "     11 +const y = 2;",
    "     12  return x;",
  }

  local loc = codex.parse_diff_location(lines, 2) -- line 10 (unchanged)
  eq(loc.filepath, "src/app.ts")
  eq(loc.lnum, 10)
end

-- Added/Deleted file

T["parse_diff_location works with Added header"] = function()
  local codex = require("aibo.internal.codex_cli")
  local lines = {
    "• Added src/new-file.ts (+3 -0)",
    "      1 +import { foo } from 'bar';",
    "      2 +",
    "      3 +export const x = 1;",
  }

  local loc = codex.parse_diff_location(lines, 4)
  eq(loc.filepath, "src/new-file.ts")
  eq(loc.lnum, 3)
end

T["parse_diff_location works with Deleted header"] = function()
  local codex = require("aibo.internal.codex_cli")
  local lines = {
    "• Deleted src/old-file.ts (+0 -3)",
    "      1 -const a = 1;",
    "      2 -const b = 2;",
    "      3 -const c = 3;",
  }

  local loc = codex.parse_diff_location(lines, 2)
  eq(loc.filepath, "src/old-file.ts")
  eq(loc.lnum, 1)
end

-- Multi-file

T["parse_diff_location finds nearest sub-header in multi-file diff"] = function()
  local codex = require("aibo.internal.codex_cli")
  local lines = {
    "• Edited 2 files (+5 -2)",
    "",
    "  └ src/app.ts (+3 -1)",
    "     10  const x = 1;",
    "     11 -const y = 2;",
    "     12 +const y = 3;",
    "",
    "  └ src/utils.ts (+2 -1)",
    "      5  function foo() {",
    "      6 -  return null;",
    "      7 +  return 42;",
  }

  -- Line in second file block
  local loc = codex.parse_diff_location(lines, 11) -- line 7 in utils.ts
  eq(loc.filepath, "src/utils.ts")
  eq(loc.lnum, 7)

  -- Line in first file block
  local loc2 = codex.parse_diff_location(lines, 6) -- line 12 in app.ts
  eq(loc2.filepath, "src/app.ts")
  eq(loc2.lnum, 12)
end

T["parse_diff_location skips multi-file summary header"] = function()
  local codex = require("aibo.internal.codex_cli")
  -- If somehow a content line appears directly after the summary (shouldn't happen),
  -- the parser should not use the summary "2 files" as a file path.
  local lines = {
    "• Edited 2 files (+5 -2)",
    "      1 +orphan line",
  }

  -- Should return nil because "2 files" is not a valid filepath
  eq(codex.parse_diff_location(lines, 2), nil)
end

-- Hunk separator

T["parse_diff_location works across hunk separator"] = function()
  local codex = require("aibo.internal.codex_cli")
  local lines = {
    "• Edited src/app.ts (+2 -0)",
    "      5  line five",
    "        ⋮",
    "     50 +new line fifty",
  }

  local loc = codex.parse_diff_location(lines, 4)
  eq(loc.filepath, "src/app.ts")
  eq(loc.lnum, 50)
end

-- Edge cases

T["parse_diff_location returns nil for header line itself"] = function()
  local codex = require("aibo.internal.codex_cli")
  local lines = {
    "• Edited src/app.ts (+1 -0)",
    "      1 +code",
  }

  eq(codex.parse_diff_location(lines, 1), nil)
end

T["parse_diff_location returns nil for non-diff line"] = function()
  local codex = require("aibo.internal.codex_cli")
  local lines = {
    "• Edited src/app.ts (+1 -0)",
    "Some random text",
  }

  eq(codex.parse_diff_location(lines, 2), nil)
end

T["parse_diff_location returns nil when no header found"] = function()
  local codex = require("aibo.internal.codex_cli")
  local lines = {
    "      1 +orphan line",
  }

  eq(codex.parse_diff_location(lines, 1), nil)
end

T["parse_diff_location handles deeply nested paths"] = function()
  local codex = require("aibo.internal.codex_cli")
  local lines = {
    "• Edited packages/core/src/utils/helpers.ts (+1 -0)",
    "     42 +export function foo() {}",
  }

  local loc = codex.parse_diff_location(lines, 2)
  eq(loc.filepath, "packages/core/src/utils/helpers.ts")
  eq(loc.lnum, 42)
end

return T
