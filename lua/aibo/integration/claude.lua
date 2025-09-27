local M = {}

---@class ClaudeArgument
---@field arg string The argument flag
---@field description string Description of the argument
---@field has_value boolean Whether the argument takes a value
---@field values? string[] Possible values for the argument

-- Define meaningful Claude arguments for interactive sessions
local CLAUDE_ARGUMENTS = {
  {
    arg = "--continue",
    description = "Continue the most recent conversation",
    has_value = false,
  },
  {
    arg = "-c",
    description = "Continue the most recent conversation (short)",
    has_value = false,
  },
  {
    arg = "--resume",
    description = "Resume a conversation",
    has_value = true,
  },
  {
    arg = "-r",
    description = "Resume a conversation (short)",
    has_value = true,
  },
  {
    arg = "--fork-session",
    description = "Create new session ID when resuming",
    has_value = false,
  },
  {
    arg = "--verbose",
    description = "Override verbose mode setting",
    has_value = false,
  },
  {
    arg = "--model",
    description = "Model for the session",
    has_value = true,
    values = {
      "sonnet",
      "opus",
      "haiku",
      "claude-3-5-sonnet-latest",
      "claude-3-5-haiku-latest",
      "claude-3-opus-latest",
    },
  },
  {
    arg = "--permission-mode",
    description = "Permission mode for the session",
    has_value = true,
    values = { "default", "acceptEdits", "bypassPermissions", "plan" },
  },
  {
    arg = "--add-dir",
    description = "Additional directories to allow tool access",
    has_value = true,
  },
  {
    arg = "--ide",
    description = "Auto-connect to IDE on startup",
    has_value = false,
  },
  {
    arg = "--debug",
    description = "Enable debug mode",
    has_value = true,
  },
  {
    arg = "--settings",
    description = "Path to settings JSON file",
    has_value = true,
  },
  {
    arg = "--append-system-prompt",
    description = "Append to system prompt",
    has_value = true,
  },
  {
    arg = "--allowed-tools",
    description = "Comma-separated list of tools to allow",
    has_value = true,
  },
  {
    arg = "--disallowed-tools",
    description = "Comma-separated list of tools to deny",
    has_value = true,
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

---Check if an argument matches
---@param arg string The argument to check
---@param arg_info table The argument info containing the arg field
---@return boolean True if the argument matches
local function arg_matches(arg, arg_info)
  -- Check exact match only
  return arg == arg_info.arg
end

---Add argument completions to the list
---@param completions string[] The completions list to append to
---@param prefix string The prefix to match (empty string matches all)
local function add_argument_completions(completions, prefix)
  for _, arg_info in ipairs(CLAUDE_ARGUMENTS) do
    if prefix == "" or arg_info.arg:find("^" .. vim.pesc(prefix)) then
      table.insert(completions, arg_info.arg)
    end
  end
end

---Check if an argument requires a value
---@param arg string The argument to check
---@return boolean True if the argument requires a value
local function arg_requires_value(arg)
  for _, arg_info in ipairs(CLAUDE_ARGUMENTS) do
    if arg_matches(arg, arg_info) then
      return arg_info.has_value
    end
  end
  return false -- Unknown arguments don't require values
end

---Add value completions for a specific argument
---@param arg string The argument that needs a value
---@param prefix string The prefix to match
---@return string[]|nil Completions if found, nil otherwise
local function get_value_completions(arg, prefix)
  for _, arg_info in ipairs(CLAUDE_ARGUMENTS) do
    if arg_matches(arg, arg_info) and arg_info.has_value then
      if arg_info.values then
        -- Complete from predefined values
        local completions = {}
        for _, value in ipairs(arg_info.values) do
          if prefix == "" or value:find("^" .. vim.pesc(prefix)) then
            table.insert(completions, value)
          end
        end
        return completions
      elseif arg_info.arg == "--add-dir" then
        -- Complete directories
        return vim.fn.getcompletion(prefix, "dir")
      elseif arg_info.arg == "--settings" then
        -- Complete files
        return vim.fn.getcompletion(prefix, "file")
      else
        -- No specific completion available
        return {}
      end
    end
  end
  return nil
end

---Get completion candidates for Claude command arguments
---@param arglead string Current argument being typed
---@param cmdline string Full command line
---@param _cursorpos integer Cursor position
---@return string[] Completion candidates
function M.get_command_completions(arglead, cmdline, _cursorpos)
  local completions = {}

  -- Parse the command line
  local parts = parse_command(cmdline)
  local part_count = #parts

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

    -- Check if previous argument might need a value
    if prev_arg:match("^%-") then
      -- Check if this is a known argument
      local is_known_arg = false
      for _, arg_info in ipairs(CLAUDE_ARGUMENTS) do
        if arg_matches(prev_arg, arg_info) then
          is_known_arg = true
          break
        end
      end

      if is_known_arg then
        -- Only try to get value completions if the flag actually requires a value
        if arg_requires_value(prev_arg) then
          local value_completions = get_value_completions(prev_arg, arglead)
          if value_completions then
            return value_completions
          else
            -- Known flag that requires value but no completions available
            return {}
          end
        end
        -- If known flag doesn't require a value (boolean flag), fall through to complete other arguments
      else
        -- Unknown flag - don't provide completions
        return {}
      end
    end
  end

  -- Otherwise, complete argument names
  add_argument_completions(completions, arglead)

  return completions
end

----Check if claude command is available
----@return boolean
function M.is_available()
  return vim.fn.executable("claude") == 1
end

---Run health check for Claude integration
---@param report table Health check reporter functions
function M.check_health(report)
  report.start("Claude Integration")

  -- Check if claude command is available
  if M.is_available() then
    report.ok("claude CLI found in PATH")
    -- Note: Skipping version check as it may hang in some environments

    -- Check for API key in environment
    local api_key = vim.env.ANTHROPIC_API_KEY
    if api_key and api_key ~= "" then
      report.ok("ANTHROPIC_API_KEY environment variable is set")
    else
      report.info("ANTHROPIC_API_KEY not found in environment (may be configured in claude CLI)")
    end

    -- Check for claude config directory
    local config_dir = vim.fn.expand("~/.claude")
    if vim.fn.isdirectory(config_dir) == 1 then
      report.info(string.format("Claude config directory found: %s", config_dir))
    else
      report.info("Claude config directory not found (will be created on first use)")
    end
  else
    report.warn("claude CLI not found in PATH")
    report.info("Install claude CLI: https://github.com/anthropics/claude")
  end
end

---Setup Claude <Plug> mappings
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

  define("<Plug>(aibo-claude-mode)", "Toggle mode (Shift+Tab)", function()
    send("<S-Tab>")
  end)
  define("<Plug>(aibo-claude-verbose)", "Verbose (Ctrl+O)", function()
    send("<C-o>")
  end)
  define("<Plug>(aibo-claude-todo)", "Todo (Ctrl+T)", function()
    send("<C-t>")
  end)
  define("<Plug>(aibo-claude-undo)", "Undo (Ctrl+Y)", function()
    send("<C-y>")
  end)
  define("<Plug>(aibo-claude-paste)", "Paste (Ctrl+V)", function()
    send("<C-v>")
  end)
  define("<Plug>(aibo-claude-shortcuts)", "Shortcuts (?)", function()
    send("?")
  end)
  define("<Plug>(aibo-claude-bash-mode)", "Bash mode (!)", function()
    send("!")
  end)
  define("<Plug>(aibo-claude-memorize)", "Memorize (#)", function()
    send("#")
  end)
end

return M
