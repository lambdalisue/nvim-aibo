--- Completion module for Claude Code in aibo prompt
--- Provides omnifunc-compatible completion for "/" slash commands and "@" file paths
local M = {}

local file_completion = require("aibo.completion.file")

-- Claude Code built-in slash commands and bundled skills
-- Reference: https://code.claude.com/docs/en/commands
local BUILTIN_COMMANDS = {
  { cmd = "/add-dir", description = "Add a working directory for file access" },
  { cmd = "/agents", description = "Manage agent configurations" },
  { cmd = "/allowed-tools", description = "Manage tool permission rules (alias for /permissions)" },
  { cmd = "/android", description = "Show QR code to download the Claude mobile app (alias for /mobile)" },
  { cmd = "/app", description = "Continue the current session in the Claude Code Desktop app (alias for /desktop)" },
  { cmd = "/autofix-pr", description = "Spawn a web session that watches the PR and pushes fixes for CI failures" },
  { cmd = "/bashes", description = "List and manage background tasks (alias for /tasks)" },
  { cmd = "/batch", description = "Orchestrate large-scale changes across a codebase in parallel (skill)" },
  { cmd = "/branch", description = "Create a branch of the current conversation at this point" },
  { cmd = "/btw", description = "Ask a quick side question without adding to the conversation" },
  { cmd = "/bug", description = "Submit feedback about Claude Code (alias for /feedback)" },
  { cmd = "/checkpoint", description = "Rewind the conversation and/or code to a previous point (alias for /rewind)" },
  { cmd = "/chrome", description = "Configure Claude in Chrome settings" },
  { cmd = "/claude-api", description = "Load Claude API reference material for your project's language (skill)" },
  { cmd = "/clear", description = "Start a new conversation with empty context" },
  { cmd = "/color", description = "Set the prompt bar color for the current session" },
  { cmd = "/compact", description = "Free up context by summarizing the conversation so far" },
  { cmd = "/config", description = "Open the Settings interface" },
  { cmd = "/context", description = "Visualize current context usage as a colored grid" },
  { cmd = "/continue", description = "Resume a conversation by ID or name (alias for /resume)" },
  { cmd = "/copy", description = "Copy the last assistant response to clipboard" },
  { cmd = "/cost", description = "Show plan usage limits and activity stats (alias for /usage)" },
  { cmd = "/debug", description = "Enable debug logging and troubleshoot session issues (skill)" },
  { cmd = "/desktop", description = "Continue the current session in the Claude Code Desktop app" },
  { cmd = "/diff", description = "Open an interactive diff viewer for uncommitted and per-turn changes" },
  { cmd = "/doctor", description = "Diagnose and verify your Claude Code installation and settings" },
  { cmd = "/effort", description = "Set the model effort level" },
  { cmd = "/exit", description = "Exit the CLI" },
  { cmd = "/export", description = "Export the current conversation as plain text" },
  { cmd = "/extra-usage", description = "Configure extra usage to keep working when rate limits are hit" },
  { cmd = "/fast", description = "Toggle fast mode on or off" },
  { cmd = "/feedback", description = "Submit feedback about Claude Code" },
  {
    cmd = "/fewer-permission-prompts",
    description = "Add an allowlist for common read-only tools to project settings (skill)",
  },
  { cmd = "/focus", description = "Toggle the focus view (last prompt, tool summary, final response)" },
  { cmd = "/fork", description = "Create a branch of the current conversation (alias for /branch)" },
  { cmd = "/heapdump", description = "Write a JS heap snapshot and memory breakdown for diagnosing memory usage" },
  { cmd = "/help", description = "Show help and available commands" },
  { cmd = "/hooks", description = "View hook configurations for tool events" },
  { cmd = "/ide", description = "Manage IDE integrations and show status" },
  { cmd = "/init", description = "Initialize project with a CLAUDE.md guide" },
  { cmd = "/insights", description = "Generate a report analyzing your Claude Code sessions" },
  { cmd = "/install-github-app", description = "Set up the Claude GitHub Actions app for a repository" },
  { cmd = "/install-slack-app", description = "Install the Claude Slack app via OAuth" },
  { cmd = "/ios", description = "Show QR code to download the Claude mobile app (alias for /mobile)" },
  { cmd = "/keybindings", description = "Open or create your keybindings configuration file" },
  { cmd = "/login", description = "Sign in to your Anthropic account" },
  { cmd = "/logout", description = "Sign out from your Anthropic account" },
  { cmd = "/loop", description = "Run a prompt repeatedly while the session stays open (skill)" },
  { cmd = "/mcp", description = "Manage MCP server connections and OAuth authentication" },
  { cmd = "/memory", description = "Edit CLAUDE.md memory files and manage auto-memory entries" },
  { cmd = "/mobile", description = "Show QR code to download the Claude mobile app" },
  { cmd = "/model", description = "Select or change the AI model" },
  { cmd = "/new", description = "Start a new conversation with empty context (alias for /clear)" },
  { cmd = "/passes", description = "Share a free week of Claude Code with friends" },
  { cmd = "/permissions", description = "Manage allow, ask, and deny rules for tool permissions" },
  { cmd = "/plan", description = "Enter plan mode directly from the prompt" },
  { cmd = "/plugin", description = "Manage Claude Code plugins" },
  { cmd = "/powerup", description = "Discover Claude Code features through interactive lessons" },
  { cmd = "/privacy-settings", description = "View and update your privacy settings (Pro and Max only)" },
  { cmd = "/proactive", description = "Run a prompt repeatedly while the session stays open (alias for /loop)" },
  { cmd = "/quit", description = "Exit the CLI (alias for /exit)" },
  { cmd = "/rc", description = "Make this session available for remote control (alias for /remote-control)" },
  { cmd = "/recap", description = "Generate a one-line summary of the current session" },
  { cmd = "/release-notes", description = "View the changelog in an interactive version picker" },
  { cmd = "/reload-plugins", description = "Reload all active plugins to apply pending changes without restarting" },
  { cmd = "/remote-control", description = "Make this session available for remote control from claude.ai" },
  { cmd = "/remote-env", description = "Configure the default remote environment for web sessions" },
  { cmd = "/rename", description = "Rename the current session and show the name on the prompt bar" },
  { cmd = "/reset", description = "Start a new conversation with empty context (alias for /clear)" },
  { cmd = "/resume", description = "Resume a conversation by ID or name, or open the session picker" },
  { cmd = "/review", description = "Review a pull request locally in your current session" },
  { cmd = "/rewind", description = "Rewind the conversation and/or code to a previous point" },
  { cmd = "/routines", description = "Create, update, list, or run routines (alias for /schedule)" },
  { cmd = "/sandbox", description = "Toggle sandbox mode" },
  { cmd = "/schedule", description = "Create, update, list, or run routines" },
  {
    cmd = "/security-review",
    description = "Analyze pending changes on the current branch for security vulnerabilities",
  },
  { cmd = "/settings", description = "Open the Settings interface (alias for /config)" },
  { cmd = "/setup-bedrock", description = "Configure Amazon Bedrock authentication, region, and model pins" },
  { cmd = "/setup-vertex", description = "Configure Google Vertex AI authentication, project, and region" },
  { cmd = "/simplify", description = "Review recently changed files for reuse, quality, and efficiency (skill)" },
  { cmd = "/skills", description = "List available skills" },
  { cmd = "/stats", description = "Show plan usage limits and activity stats (alias for /usage)" },
  { cmd = "/status", description = "Open the Settings interface (Status tab)" },
  { cmd = "/statusline", description = "Configure Claude Code's status line" },
  { cmd = "/stickers", description = "Order Claude Code stickers" },
  { cmd = "/tasks", description = "List and manage background tasks" },
  { cmd = "/team-onboarding", description = "Generate a team onboarding guide from your Claude Code usage history" },
  { cmd = "/teleport", description = "Pull a Claude Code on the web session into this terminal" },
  { cmd = "/terminal-setup", description = "Configure terminal keybindings for Shift+Enter and other shortcuts" },
  { cmd = "/theme", description = "Change the color theme" },
  { cmd = "/tp", description = "Pull a Claude Code on the web session into this terminal (alias for /teleport)" },
  { cmd = "/tui", description = "Set the terminal UI renderer (default or fullscreen)" },
  {
    cmd = "/ultraplan",
    description = "Draft a plan in an ultraplan session, review it, then execute remotely or locally",
  },
  { cmd = "/ultrareview", description = "Run a deep, multi-agent code review in a cloud sandbox" },
  { cmd = "/undo", description = "Rewind the conversation and/or code to a previous point (alias for /rewind)" },
  { cmd = "/upgrade", description = "Open the upgrade page to switch to a higher plan tier" },
  { cmd = "/usage", description = "Show session cost, plan usage limits, and activity stats" },
  { cmd = "/voice", description = "Toggle voice dictation, or enable it in a specific mode" },
  {
    cmd = "/web-setup",
    description = "Connect your GitHub account to Claude Code on the web using your gh CLI credentials",
  },
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
