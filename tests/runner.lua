-- Simple test runner for aibo
-- Run with: nvim --headless -c "luafile tests/runner.lua" -c "qa!"

local M = {}

-- Get test directory
local test_file = debug.getinfo(1, "S").source:sub(2)
local test_dir = vim.fn.fnamemodify(test_file, ":h")
local project_root = vim.fn.fnamemodify(test_dir, ":h")

-- Add project root to runtimepath and package.path
vim.opt.runtimepath:prepend(project_root)
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

-- Load the plugin to register commands and setup
vim.cmd("runtime plugin/aibo.lua")

-- Mock vim.ui.select globally to prevent test hanging
local original_ui_select = vim.ui.select
vim.ui.select = function(items, opts, on_choice)
  -- In tests, always select first item immediately
  if on_choice then
    on_choice(items and items[1] or nil)
  end
end

-- Bootstrap mini.nvim if not installed (needed by test files)
local mini_path = vim.fn.stdpath("data") .. "/site/pack/deps/start/mini.nvim"
if not vim.loop.fs_stat(mini_path) then
  print("Installing mini.nvim...")
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/echasnovski/mini.nvim",
    mini_path,
  })
end
vim.cmd("packadd mini.nvim")

-- Load mini.test (needed by test files for T.expect)
local ok, mini_test = pcall(require, "mini.test")
if not ok then
  print("Failed to load mini.test: " .. tostring(mini_test))
  vim.cmd("cquit 1")
  return
end

-- Initialize mini.test but DON'T use mini_test.run() to avoid recursion
mini_test.setup()

-- Provide T globally for tests
_G.T = mini_test

-- List of test files organized by category
local test_files = {
  -- Internal module tests
  "internal/test_init",
  "internal/test_argparse",
  "internal/test_console_window",
  "internal/test_prompt_window",
  "internal/test_timing",

  -- Command tests
  "commands/test_aibo_command",
  "commands/test_aibo_send_command",

  -- Integration tests
  "integrations/test_claude",
  "integrations/test_codex",
  "integrations/test_ollama",

  -- Plugin tests
  "plugin/test_plugin_setup",
}

-- Results tracking
local total_tests = 0
local passed_tests = 0
local failed_tests = 0
local errors = {}

-- Simple test runner
for _, file in ipairs(test_files) do
  local test_path = test_dir .. "/" .. file .. ".lua"
  local ok, test_set = pcall(dofile, test_path)

  if ok and test_set then
    print("\nRunning " .. file .. "...")

    -- Run each test in the set
    for test_name, test_fn in pairs(test_set) do
      if type(test_fn) == "function" and test_name ~= "hooks" then
        total_tests = total_tests + 1

        -- Run pre_case hook for each test
        if test_set.hooks and test_set.hooks.pre_case then
          pcall(test_set.hooks.pre_case)
        end

        -- Run the test
        local test_ok, test_err = pcall(test_fn)

        -- Run post_case hook for each test
        if test_set.hooks and test_set.hooks.post_case then
          pcall(test_set.hooks.post_case)
        end

        if test_ok then
          passed_tests = passed_tests + 1
          print("  ✓ " .. test_name)
        else
          failed_tests = failed_tests + 1
          print("  ✗ " .. test_name)
          table.insert(errors, {
            file = file,
            test = test_name,
            error = test_err,
          })
        end
      end
    end
  else
    print("Failed to load " .. file .. ": " .. tostring(test_set))
  end
end

-- Print summary
print("\n" .. string.rep("=", 50))
print("Test Summary:")
print("  Total: " .. total_tests)
print("  Passed: " .. passed_tests)
print("  Failed: " .. failed_tests)

-- Print errors if any
if #errors > 0 then
  print("\nErrors:")
  for _, err in ipairs(errors) do
    print("\n  " .. err.file .. " - " .. err.test .. ":")
    print("    " .. tostring(err.error))
  end
  vim.cmd("cquit 1")
else
  print("\nAll tests passed!")
  vim.cmd("qa!") -- Exit successfully
end

-- Don't return anything to avoid mini.test thinking this is a test module
-- The test runner should just execute and exit
