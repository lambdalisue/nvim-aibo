local M = {}

---@class OllamaArgument
---@field arg string The argument flag
---@field description string Description of the argument
---@field has_value boolean Whether the argument takes a value
---@field values? string[] Possible values for the argument

-- Define meaningful Ollama arguments for interactive sessions with "ollama run"
local OLLAMA_ARGUMENTS = {
  {
    arg = "run",
    description = "Run a model",
    has_value = true,
    is_subcommand = true,
  },
  {
    arg = "--format",
    description = "Response format (e.g. json)",
    has_value = true,
    values = { "json" },
  },
  {
    arg = "--hidethinking",
    description = "Hide thinking output",
    has_value = false,
  },
  {
    arg = "--keepalive",
    description = "Duration to keep model loaded",
    has_value = true,
    values = { "5m", "10m", "30m", "1h", "24h" },
  },
  {
    arg = "--nowordwrap",
    description = "Don't wrap words automatically",
    has_value = false,
  },
  {
    arg = "--think",
    description = "Enable thinking mode",
    has_value = true,
    values = { "true", "false", "high", "medium", "low" },
  },
  {
    arg = "--verbose",
    description = "Show response timings",
    has_value = false,
  },
}

---Get list of locally available Ollama models
---@return string[]
local function get_local_models()
  local result = vim.fn.system({ "ollama", "list" })
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local models = {}
  local lines = vim.split(result, "\n")
  -- Skip the header line
  for i = 2, #lines do
    local line = lines[i]
    if line and line ~= "" then
      -- Extract model name (first column)
      local model_name = line:match("^([^%s]+)")
      if model_name then
        table.insert(models, model_name)
      end
    end
  end

  return models
end

---Add model completions to the list
---@param completions string[] The completions list to append to
---@param prefix string The prefix to match (empty string matches all)
local function add_model_completions(completions, prefix)
  local models = get_local_models()
  for _, model in ipairs(models) do
    if prefix == "" or model:find("^" .. vim.pesc(prefix)) then
      table.insert(completions, model)
    end
  end
end

---Add flag completions to the list
---@param completions string[] The completions list to append to
---@param prefix string The prefix to match (empty string matches all)
local function add_flag_completions(completions, prefix)
  for _, arg_info in ipairs(OLLAMA_ARGUMENTS) do
    if not arg_info.is_subcommand then
      if prefix == "" or arg_info.arg:find("^" .. vim.pesc(prefix)) then
        table.insert(completions, arg_info.arg)
      end
    end
  end
end

---Add flag value completions for a specific flag
---@param completions string[] The completions list to append to
---@param flag string The flag that needs a value
---@param prefix string The prefix to match (empty string matches all)
---@return boolean True if flag values were added
local function add_flag_value_completions(completions, flag, prefix)
  for _, arg_info in ipairs(OLLAMA_ARGUMENTS) do
    if not arg_info.is_subcommand and flag == arg_info.arg and arg_info.has_value then
      if arg_info.values then
        for _, value in ipairs(arg_info.values) do
          if prefix == "" or value:find("^" .. vim.pesc(prefix)) then
            table.insert(completions, value)
          end
        end
      end
      return true
    end
  end
  return false
end

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

---Check if ollama command is available
---@return boolean
function M.is_available()
  return vim.fn.executable("ollama") == 1
end

---Get completion candidates for Ollama command arguments
---@param arglead string Current argument being typed
---@param cmdline string Full command line
---@param _cursorpos integer Cursor position
---@return string[] Completion candidates
function M.get_command_completions(arglead, cmdline, _cursorpos)
  local completions = {}

  -- Check for trailing space to understand if we're starting a new argument
  local has_trailing_space = cmdline:match("%s$") ~= nil

  -- Parse the command line into parts
  local parts = parse_command(cmdline)
  local part_count = #parts

  -- Position 1: After "ollama"
  if part_count == 1 then
    if has_trailing_space or arglead == "" then
      -- Complete the subcommand "run"
      table.insert(completions, "run")
    end

    -- Position 2: After "ollama [run|partial]"
  elseif part_count == 2 then
    local second_arg = parts[2]

    if second_arg ~= "run" then
      -- Complete partial "run" command
      if string.find("run", "^" .. vim.pesc(second_arg)) then
        table.insert(completions, "run")
      end
    elseif has_trailing_space or arglead == "" then
      -- After "ollama run " - show models and flags
      add_model_completions(completions, "")
      add_flag_completions(completions, "")
    end

    -- Position 3+: After "ollama run ..."
  elseif part_count >= 3 and parts[2] == "run" then
    if arglead ~= "" then
      -- Completing a partial argument - could be model or flag
      add_model_completions(completions, arglead)
      add_flag_completions(completions, arglead)

      -- Also check if we're completing a flag value
      local prev_arg = parts[part_count - 1]
      add_flag_value_completions(completions, prev_arg, arglead)
    else
      -- Check if previous argument is a flag that needs a value
      local prev_arg = has_trailing_space and parts[part_count] or parts[part_count - 1]
      if not add_flag_value_completions(completions, prev_arg, "") then
        -- No flag value needed, show available flags
        add_flag_completions(completions, "")
      end
    end
  end

  return completions
end

return M
