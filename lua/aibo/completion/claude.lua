--- Completion module for Claude Code slash commands in aiboprompt
--- Provides omnifunc-compatible completion for "/" commands
local M = {}

-- Claude Code built-in slash commands
-- Reference: https://docs.anthropic.com/en/docs/claude-code/cli-usage
local BUILTIN_COMMANDS = {
  { cmd = "/add-dir", description = "Add a directory to Claude's context" },
  { cmd = "/bug", description = "Report bugs (opens GitHub)" },
  { cmd = "/clear", description = "Clear conversation history" },
  { cmd = "/compact", description = "Clear context and compact the conversation" },
  { cmd = "/config", description = "View/modify Claude Code configuration" },
  { cmd = "/cost", description = "Show current session cost statistics" },
  { cmd = "/doctor", description = "Diagnose common issues with Claude Code" },
  { cmd = "/help", description = "Get usage help" },
  { cmd = "/ide", description = "Connect Claude to an IDE" },
  { cmd = "/init", description = "Initialize project with CLAUDE.md guide" },
  { cmd = "/login", description = "Login to Anthropic" },
  { cmd = "/logout", description = "Logout from Anthropic" },
  { cmd = "/memory", description = "Edit CLAUDE.md memory files" },
  { cmd = "/mcp", description = "View configured MCP servers" },
  { cmd = "/model", description = "Switch AI model" },
  { cmd = "/permissions", description = "Manage tool permissions" },
  { cmd = "/pr-comments", description = "View pull request comments" },
  { cmd = "/release-notes", description = "View latest release notes" },
  { cmd = "/resume", description = "Resume a previous conversation" },
  { cmd = "/review", description = "Request code review" },
  { cmd = "/status", description = "View account and system status" },
  { cmd = "/tasks", description = "List background tasks" },
  { cmd = "/terminal-setup", description = "Install Shift+Enter key binding" },
  { cmd = "/vim", description = "Enter vim mode for multi-line editing" },
}

---Extract description from command file
---@param file string Path to the command file
---@return string Description
local function extract_description(file)
  local lines = vim.fn.readfile(file, "", 20) -- Read up to 20 lines for front matter
  local description = nil

  -- Check for YAML front matter
  if lines[1] == "---" then
    for i = 2, #lines do
      if lines[i] == "---" then
        break
      end
      -- Look for description field in YAML
      local desc = lines[i]:match("^description:%s*(.+)$")
      if desc then
        description = vim.trim(desc)
        break
      end
    end
  else
    -- No front matter, try first line as description
    local first_line = lines[1] or ""
    first_line = first_line:gsub("^<!%-%-", ""):gsub("%-%->$", ""):gsub("^#+ *", "")
    first_line = vim.trim(first_line)
    if first_line ~= "" and first_line ~= "---" then
      description = first_line
    end
  end

  return description or "Custom command"
end

---Find custom slash commands from .claude/commands directories
---@return table[] List of custom command definitions
local function find_custom_commands()
  local commands = {}

  -- Search locations for custom commands
  local search_paths = {
    vim.fn.expand("~/.claude/commands"), -- User global commands
    vim.fn.getcwd() .. "/.claude/commands", -- Project commands
  }

  for _, dir in ipairs(search_paths) do
    if vim.fn.isdirectory(dir) == 1 then
      -- Find .md files in root and subdirectories (namespace:command format)
      local files = vim.fn.glob(dir .. "/**/*.md", false, true)
      for _, file in ipairs(files) do
        -- Get relative path from commands dir
        local rel_path = file:sub(#dir + 2) -- +2 for trailing slash
        local name_with_ext = rel_path:gsub("/", ":") -- Convert path separators to colons
        local name = name_with_ext:gsub("%.md$", "") -- Remove .md extension

        local description = extract_description(file)
        table.insert(commands, {
          cmd = "/" .. name,
          description = description .. " (custom)",
        })
      end
    end
  end

  return commands
end

---Get all slash commands (built-in + custom)
---@return table[] List of all command definitions
local function get_all_commands()
  local commands = vim.deepcopy(BUILTIN_COMMANDS)
  local custom = find_custom_commands()
  for _, cmd in ipairs(custom) do
    table.insert(commands, cmd)
  end
  return commands
end

---Get completions for slash commands
---@param base string The text to complete (should start with "/")
---@return table[] List of completion items
local function get_slash_completions(base)
  local completions = {}
  local prefix = base:lower()
  local all_commands = get_all_commands()

  for _, item in ipairs(all_commands) do
    if item.cmd:lower():find(prefix, 1, true) == 1 then
      table.insert(completions, {
        word = item.cmd,
        menu = item.description,
        kind = "Slash",
      })
    end
  end

  return completions
end

---Check if the cursor is at a position where slash command completion should trigger
---@param line string Current line content
---@param col number Cursor column (1-indexed)
---@return number|nil Start column of the slash command, or nil if not applicable
local function find_slash_start(line, col)
  local before_cursor = line:sub(1, col - 1)

  -- Find "/" at start of line or after whitespace
  local slash_pos = nil
  for i = #before_cursor, 1, -1 do
    local char = before_cursor:sub(i, i)
    if char == "/" then
      if i == 1 or before_cursor:sub(i - 1, i - 1):match("%s") then
        slash_pos = i
        break
      end
    elseif char:match("%s") then
      break
    end
  end

  return slash_pos
end

---Omnifunc for slash command completion
---@param findstart number 1 to find start position, 0 to get completions
---@param base string The text to complete (only used when findstart is 0)
---@return number|table Start position or completion list
function M.omnifunc(findstart, base)
  if findstart == 1 then
    local line = vim.api.nvim_get_current_line()
    local col = vim.fn.col(".")
    local start = find_slash_start(line, col)

    if start then
      return start - 1 -- Convert to 0-indexed
    end

    return -3
  else
    if base:sub(1, 1) ~= "/" then
      base = "/" .. base
    end
    return get_slash_completions(base)
  end
end

---Get raw list of slash commands (for external use)
---@return table[] List of slash command definitions
function M.get_commands()
  return get_all_commands()
end

return M
