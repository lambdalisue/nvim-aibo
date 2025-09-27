-- Tests for Ollama integration (lua/aibo/integration/ollama.lua)

local mock = require("tests.mock")
local T = require("mini.test")

-- Test set
local test_set = T.new_set({
  hooks = {
    post_case = function()
      vim.cmd("silent! %bwipeout!")
    end,
  },
})

-- Test Ollama is_available
test_set["Ollama is_available"] = function()
  local ollama = require("aibo.integration.ollama")

  -- Mock executable using mock.lua
  local restore = mock.mock_executable({
    ollama = true,
  })

  T.expect.equality(ollama.is_available(), true, "Should be available when ollama exists")

  -- Test when not available
  vim.fn.executable = function()
    return 0
  end
  T.expect.equality(ollama.is_available(), false, "Should not be available when ollama missing")

  restore()
end

-- Test Ollama run subcommand completion
test_set["Ollama run subcommand completion"] = function()
  local ollama = require("aibo.integration.ollama")

  -- Test completing "run" after "ollama"
  local completions = ollama.get_command_completions("", "ollama ", 7)
  T.expect.equality(#completions, 1)
  T.expect.equality(completions[1], "run")

  -- Test partial "run" completion
  completions = ollama.get_command_completions("r", "ollama r", 8)
  T.expect.equality(#completions, 1)
  T.expect.equality(completions[1], "run")

  -- Test with "ru"
  completions = ollama.get_command_completions("ru", "ollama ru", 9)
  T.expect.equality(#completions, 1)
  T.expect.equality(completions[1], "run")
end

-- Test Ollama model completions
test_set["Ollama model completions"] = function()
  local ollama = require("aibo.integration.ollama")

  -- Mock ollama list output
  local restore = mock.mock_system({
    ["ollama list"] = {
      result = [[NAME                  ID              SIZE      MODIFIED
llama3:latest         abc123          5.5 GB    2 days ago
mistral:latest        def456          4.1 GB    1 week ago
qwen3:latest          ghi789          5.2 GB    3 months ago]],
      error = 0,
    },
  })

  -- Test completing models after "run"
  local completions = ollama.get_command_completions("", "ollama run ", 11)
  T.expect.equality(vim.tbl_contains(completions, "llama3:latest"), true)
  T.expect.equality(vim.tbl_contains(completions, "mistral:latest"), true)
  T.expect.equality(vim.tbl_contains(completions, "qwen3:latest"), true)
  T.expect.equality(vim.tbl_contains(completions, "--format"), true) -- Should also include flags

  -- Test partial model completion
  completions = ollama.get_command_completions("ll", "ollama run ll", 13)
  T.expect.equality(vim.tbl_contains(completions, "llama3:latest"), true)
  T.expect.equality(vim.tbl_contains(completions, "mistral:latest"), false)

  -- Test completion starting with "q"
  completions = ollama.get_command_completions("q", "ollama run q", 12)
  T.expect.equality(vim.tbl_contains(completions, "qwen3:latest"), true)
  T.expect.equality(vim.tbl_contains(completions, "llama3:latest"), false)

  restore()
end

-- Test Ollama flag completions
test_set["Ollama flag completions"] = function()
  local ollama = require("aibo.integration.ollama")

  -- Mock ollama list for models
  local restore = mock.mock_system({
    ["ollama list"] = {
      result = "NAME ID SIZE MODIFIED\nllama3:latest abc123 5.5GB 2 days ago",
      error = 0,
    },
  })

  -- Test flag completion after model
  local completions = ollama.get_command_completions("", "ollama run llama3:latest ", 26)
  T.expect.equality(vim.tbl_contains(completions, "--format"), true)
  T.expect.equality(vim.tbl_contains(completions, "--verbose"), true)
  T.expect.equality(vim.tbl_contains(completions, "--keepalive"), true)
  T.expect.equality(vim.tbl_contains(completions, "--think"), true)

  -- Test partial flag completion
  completions = ollama.get_command_completions("--v", "ollama run llama3:latest --v", 29)
  T.expect.equality(vim.tbl_contains(completions, "--verbose"), true)
  T.expect.equality(vim.tbl_contains(completions, "--format"), false)

  -- Test flags starting with --k
  completions = ollama.get_command_completions("--k", "ollama run llama3:latest --k", 29)
  T.expect.equality(vim.tbl_contains(completions, "--keepalive"), true)
  T.expect.equality(vim.tbl_contains(completions, "--verbose"), false)

  restore()
end

-- Test Ollama flag value completions
test_set["Ollama flag value completions"] = function()
  local ollama = require("aibo.integration.ollama")

  -- Mock ollama list to avoid executing ollama
  local restore = mock.mock_system({
    ["ollama list"] = {
      result = "NAME ID SIZE MODIFIED\nllama3:latest abc123 5.5GB 2 days ago",
      error = 0,
    },
  })

  -- Test format value completion
  local completions = ollama.get_command_completions("", "ollama run llama3 --format ", 28)
  T.expect.equality(vim.tbl_contains(completions, "json"), true)

  -- Test keepalive value completion
  completions = ollama.get_command_completions("", "ollama run llama3 --keepalive ", 31)
  T.expect.equality(vim.tbl_contains(completions, "5m"), true)
  T.expect.equality(vim.tbl_contains(completions, "10m"), true)
  T.expect.equality(vim.tbl_contains(completions, "1h"), true)
  T.expect.equality(vim.tbl_contains(completions, "24h"), true)

  -- Test think value completion
  completions = ollama.get_command_completions("", "ollama run llama3 --think ", 27)
  T.expect.equality(vim.tbl_contains(completions, "true"), true)
  T.expect.equality(vim.tbl_contains(completions, "false"), true)
  T.expect.equality(vim.tbl_contains(completions, "high"), true)
  T.expect.equality(vim.tbl_contains(completions, "medium"), true)
  T.expect.equality(vim.tbl_contains(completions, "low"), true)

  -- Test partial value completion
  completions = ollama.get_command_completions("h", "ollama run llama3 --think h", 28)
  T.expect.equality(vim.tbl_contains(completions, "high"), true)
  T.expect.equality(vim.tbl_contains(completions, "low"), false)

  restore()
end

-- Test Ollama with no models available
test_set["Ollama no models available"] = function()
  local ollama = require("aibo.integration.ollama")

  -- Mock empty ollama list
  local restore = mock.mock_system({
    ["ollama list"] = {
      result = "NAME ID SIZE MODIFIED\n",
      error = 0,
    },
  })

  -- Should still show flags even with no models
  local completions = ollama.get_command_completions("", "ollama run ", 11)
  T.expect.equality(vim.tbl_contains(completions, "--format"), true)
  T.expect.equality(vim.tbl_contains(completions, "--verbose"), true)

  restore()
end

return test_set
