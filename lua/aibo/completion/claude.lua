--- Completion module for Claude Code in aibo prompt
--- Provides omnifunc-compatible completion for "/" slash commands and "@" file paths
local M = {}

local file_completion = require("aibo.completion.file")

-- Claude Code built-in slash commands
-- Reference: https://code.claude.com/docs/en/interactive-mode#built-in-commands
local BUILTIN_COMMANDS = {
  { cmd = "/add-dir", description = "Add a directory to Claude's context" },
  { cmd = "/bug", description = "Report bugs (opens GitHub)" },
  { cmd = "/clear", description = "Clear conversation history" },
  { cmd = "/compact", description = "Compact conversation with optional focus instructions" },
  { cmd = "/config", description = "Open the Settings interface (Config tab)" },
  { cmd = "/context", description = "Visualize current context usage as a colored grid" },
  { cmd = "/copy", description = "Copy the last assistant response to clipboard" },
  { cmd = "/cost", description = "Show token usage statistics" },
  { cmd = "/debug", description = "Troubleshoot the current session by reading the debug log" },
  { cmd = "/desktop", description = "Hand off the current CLI session to the Claude Code Desktop app" },
  { cmd = "/doctor", description = "Checks the health of your Claude Code installation" },
  { cmd = "/exit", description = "Exit the REPL" },
  { cmd = "/export", description = "Export the current conversation to a file or clipboard" },
  { cmd = "/help", description = "Get usage help" },
  { cmd = "/ide", description = "Connect Claude to an IDE" },
  { cmd = "/init", description = "Initialize project with CLAUDE.md guide" },
  { cmd = "/login", description = "Login to Anthropic" },
  { cmd = "/logout", description = "Logout from Anthropic" },
  { cmd = "/mcp", description = "Manage MCP server connections and OAuth authentication" },
  { cmd = "/memory", description = "Edit CLAUDE.md memory files" },
  { cmd = "/model", description = "Select or change the AI model" },
  { cmd = "/permissions", description = "View or update permissions" },
  { cmd = "/plan", description = "Enter plan mode directly from the prompt" },
  { cmd = "/pr-comments", description = "View pull request comments" },
  { cmd = "/release-notes", description = "View latest release notes" },
  { cmd = "/rename", description = "Rename the current session for easier identification" },
  { cmd = "/resume", description = "Resume a conversation by ID or name" },
  { cmd = "/review", description = "Request code review" },
  { cmd = "/rewind", description = "Rewind the conversation and/or code" },
  { cmd = "/stats", description = "Visualize daily usage, session history, streaks, and model preferences" },
  { cmd = "/status", description = "Open the Settings interface (Status tab)" },
  { cmd = "/statusline", description = "Set up Claude Code's status line UI" },
  { cmd = "/tasks", description = "List and manage background tasks" },
  { cmd = "/teleport", description = "Resume a remote session from claude.ai" },
  { cmd = "/terminal-setup", description = "Install Shift+Enter key binding" },
  { cmd = "/theme", description = "Change the color theme" },
  { cmd = "/todos", description = "List current TODO items" },
  { cmd = "/usage", description = "Show plan usage limits and rate limit status" },
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
  local seen = {}

  -- Search locations for custom commands (personal takes precedence over project)
  local search_paths = {
    vim.fn.expand("~/.claude/commands"), -- User personal commands
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

        if not seen[name] then
          seen[name] = true
          local description = extract_description(file)
          table.insert(commands, {
            cmd = "/" .. name,
            description = description .. " (custom)",
          })
        end
      end
    end
  end

  return commands
end

---Find custom skills from .claude/skills directories
---Skills use the structure: .claude/skills/<skill-name>/SKILL.md
---@return table[] List of custom skill definitions
local function find_custom_skills()
  local skills = {}
  local seen = {}

  -- Personal takes precedence over project
  local search_paths = {
    vim.fn.expand("~/.claude/skills"), -- User personal skills
    vim.fn.getcwd() .. "/.claude/skills", -- Project skills
  }

  for _, dir in ipairs(search_paths) do
    if vim.fn.isdirectory(dir) == 1 then
      local files = vim.fn.glob(dir .. "/*/SKILL.md", false, true)
      for _, file in ipairs(files) do
        -- Extract skill name from parent directory
        local name = vim.fn.fnamemodify(file, ":h:t")

        if not seen[name] then
          seen[name] = true
          local description = extract_description(file)
          table.insert(skills, {
            cmd = "/" .. name,
            description = description .. " (skill)",
          })
        end
      end
    end
  end

  return skills
end

---Get all slash commands (built-in + custom + skills)
---@return table[] List of all command definitions
local function get_all_commands()
  local commands = vim.deepcopy(BUILTIN_COMMANDS)
  local custom = find_custom_commands()
  for _, cmd in ipairs(custom) do
    table.insert(commands, cmd)
  end
  local skills = find_custom_skills()
  for _, cmd in ipairs(skills) do
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

---Omnifunc for integrated completion (slash commands + file paths)
---@param findstart number 1 to find start position, 0 to get completions
---@param base string The text to complete (only used when findstart is 0)
---@return number|table Start position or completion list
function M.omnifunc(findstart, base)
  if findstart == 1 then
    local line = vim.api.nvim_get_current_line()
    local col = vim.fn.col(".")

    -- Check @ file completion first (since @/ contains "/" which could match slash)
    local at_start = file_completion.find_at_start(line, col)
    if at_start then
      return at_start - 1 -- Convert to 0-indexed
    end

    -- Then check / slash command completion
    local slash_start = find_slash_start(line, col)
    if slash_start then
      return slash_start - 1 -- Convert to 0-indexed
    end

    return -3
  else
    -- Route to appropriate completion based on trigger character
    if base:sub(1, 1) == "@" then
      return file_completion.get_completions(base)
    end

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
