local M = {}

---@class CodexArgument
---@field arg string The argument flag
---@field description string Description of the argument
---@field has_value boolean Whether the argument takes a value
---@field values? string[] Possible values for the argument

-- Define OpenAI Codex CLI arguments for interactive sessions
-- https://github.com/openai/codex
local CODEX_ARGUMENTS = {
  -- Interactive subcommands
  {
    arg = "resume",
    description = "Resume a previous session",
    has_value = false,
    is_subcommand = true,
  },
  -- Main flags
  {
    arg = "--model",
    description = "Select model to use",
    has_value = true,
  },
  {
    arg = "-m",
    description = "Select model to use (short)",
    has_value = true,
  },
  {
    arg = "--ask-for-approval",
    description = "Request approval before executing commands",
    has_value = false,
  },
  {
    arg = "-a",
    description = "Request approval (short)",
    has_value = false,
  },
  {
    arg = "--cd",
    description = "Specify working directory",
    has_value = true,
  },
  {
    arg = "-C",
    description = "Specify working directory (short)",
    has_value = true,
  },
  {
    arg = "--full-auto",
    description = "Automatic execution mode without confirmations",
    has_value = false,
  },
  {
    arg = "--image",
    description = "Attach image(s) to initial prompt",
    has_value = true,
  },
  {
    arg = "-i",
    description = "Attach image(s) (short)",
    has_value = true,
  },
  -- Resume-specific options
  {
    arg = "--last",
    description = "Resume the most recent session (use with resume)",
    has_value = false,
    is_resume_option = true,
  },
}

---Parse command line into parts
---@param cmdline string The full command line
---@return string[] The parsed parts
local function parse_command(cmdline)
  local parts = {}
  for part in cmdline:gmatch("%S+") do
    table.insert(parts, part)
  end
  return parts
end

---Check if an argument matches (handling both long and short forms)
---@param arg string The argument to check
---@param arg_info table The argument info containing the arg field
---@return boolean True if the argument matches
local function arg_matches(arg, arg_info)
  -- Check exact match or short form match
  return arg == arg_info.arg or arg == arg_info.arg:gsub("%-%-", "-")
end

---Add subcommand completions to the list
---@param completions string[] The completions list to append to
---@param prefix string The prefix to match (empty string matches all)
local function add_subcommand_completions(completions, prefix)
  -- Handle interactive subcommands only: resume
  if prefix == "" or string.find("resume", "^" .. vim.pesc(prefix)) then
    table.insert(completions, "resume")
  end
end

---Add argument completions to the list
---@param completions string[] The completions list to append to
---@param prefix string The prefix to match (empty string matches all)
local function add_argument_completions(completions, prefix)
  for _, arg_info in ipairs(CODEX_ARGUMENTS) do
    if not arg_info.is_subcommand then
      if prefix == "" or arg_info.arg:find("^" .. vim.pesc(prefix)) then
        table.insert(completions, arg_info.arg)
      end
    end
  end
end

---Get value completions for a specific argument
---@param arg string The argument that needs a value
---@param prefix string The prefix to match
---@param _context table Additional context (e.g., current subcommand)
---@return string[]|nil Completions if found, nil otherwise
local function get_value_completions(arg, prefix, _context)
  for _, arg_info in ipairs(CODEX_ARGUMENTS) do
    if not arg_info.is_subcommand and arg_matches(arg, arg_info) and arg_info.has_value then
      if arg_info.arg == "--image" or arg_info.arg == "-i" then
        -- Complete image files
        return vim.fn.getcompletion(prefix, "file")
      elseif arg_info.arg == "--cd" or arg_info.arg == "-C" then
        -- Complete directories
        return vim.fn.getcompletion(prefix, "dir")
      else
        -- No specific completion available
        return {}
      end
    end
  end

  return nil
end

---Check if codex command is available
---@return boolean
function M.is_available()
  return vim.fn.executable("codex") == 1
end

---Get completion candidates for Codex command arguments
---@param arglead string Current argument being typed
---@param cmdline string Full command line
---@param _cursorpos integer Cursor position
---@return string[] Completion candidates
function M.get_command_completions(arglead, cmdline, _cursorpos)
  local completions = {}

  -- Parse the command line
  local parts = parse_command(cmdline)
  local part_count = #parts

  -- Determine context (current subcommand if any)
  local context = {}
  local has_subcommand = false
  for part in ipairs(parts) do
    if part == "resume" then
      context.subcommand = part
      has_subcommand = true
      break
    end
  end

  -- Check if we're completing a value for the previous argument
  if part_count >= 2 then
    local prev_arg
    if arglead == parts[part_count] then
      -- We're completing the current partial argument
      prev_arg = parts[part_count - 1] or ""
    else
      -- We have a trailing space, check the last complete argument
      prev_arg = parts[part_count] or ""
    end

    local value_completions = get_value_completions(prev_arg, arglead, context)
    if value_completions then
      return value_completions
    end
  end

  -- Handle resume subcommand special options
  if context.subcommand == "resume" then
    if arglead == "" or string.find("--last", "^" .. vim.pesc(arglead)) then
      table.insert(completions, "--last")
    end
    -- Could also complete session IDs here if we had access to them
  end

  -- If no subcommand yet, offer subcommands first
  if not has_subcommand then
    add_subcommand_completions(completions, arglead)
  end

  -- Add argument completions (flags)
  add_argument_completions(completions, arglead)

  return completions
end

---Run health check for Codex integration
---@param report table Health check reporter functions
function M.check_health(report)
  report.start("OpenAI Codex Integration")

  -- Check if codex command is available
  if M.is_available() then
    report.ok("codex CLI found in PATH")
    -- Note: Skipping version check as it may hang in some environments

    -- Check for OpenAI API key (primary authentication method)
    local openai_key = vim.env.OPENAI_API_KEY
    if openai_key and openai_key ~= "" then
      report.ok("OPENAI_API_KEY found in environment")
    else
      report.info("OPENAI_API_KEY not found (can sign in with ChatGPT account instead)")
    end

    -- Check for codex config file
    local config_file = vim.fn.expand("~/.codex/config.toml")
    if vim.fn.filereadable(config_file) == 1 then
      report.ok(string.format("Codex config file found: %s", config_file))
    else
      config_file = vim.fn.expand("~/.config/codex/config.toml")
      if vim.fn.filereadable(config_file) == 1 then
        report.ok(string.format("Codex config file found: %s", config_file))
      else
        report.info("Codex config file not found (will use defaults)")
      end
    end

    -- Check for Node.js (required for npm installation)
    if vim.fn.executable("node") == 1 then
      report.info("Node.js found - can install/update via: npm install -g @openai/codex")
    end
  else
    report.warn("codex CLI not found in PATH")
    report.info("Install OpenAI Codex CLI:")
    report.info("  npm: npm install -g @openai/codex")
    report.info("  brew: brew install codex")
    report.info("  GitHub: https://github.com/openai/codex")
  end
end

---Setup Codex <Plug> mappings
---@param bufnr number Buffer number to set mappings for
function M.setup_mappings(bufnr)
  local aibo = require("aibo")

  local define = function(lhs, desc, rhs)
    vim.keymap.set({ "n", "i" }, lhs, rhs, {
      buffer = bufnr,
      desc = desc,
      silent = true,
    })
  end

  local send = function(key)
    local code = aibo.termcode.resolve(key)
    aibo.send(code, bufnr)
  end

  define("<Plug>(aibo-codex-transcript)", "Transcript (Ctrl+T)", function()
    send("<C-t>")
  end)
  define("<Plug>(aibo-codex-home)", "Home", function()
    send("<Home>")
  end)
  define("<Plug>(aibo-codex-end)", "End", function()
    send("<End>")
  end)
  define("<Plug>(aibo-codex-page-up)", "Page up", function()
    send("<PageUp>")
  end)
  define("<Plug>(aibo-codex-page-down)", "Page down", function()
    send("<PageDown>")
  end)
  define("<Plug>(aibo-codex-quit)", "Quit", function()
    send("q")
  end)
end

return M
