local M = {}

local health = vim.health or require("health")
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error
local info = health.info or health.report_info

---Check if a command exists in the system
---@param cmd string Command name to check
---@return boolean True if command exists
local function command_exists(cmd)
  return vim.fn.executable(cmd) == 1
end

---Get version of a command (disabled due to potential hanging)
---@param _cmd string Command name
---@param _args string[] Arguments to get version
---@return string|nil Version string or nil if failed
local function get_command_version(_cmd, _args)
  -- Disabled: system calls for version can hang in some environments
  return nil
end

function M.check()
  start("aibo")

  -- Check Neovim version
  info("Neovim version: " .. vim.fn.execute("version"):match("NVIM v[^\n]+"))
  if vim.fn.has("nvim-0.10.0") == 1 then
    ok("Neovim 0.10.0+ found")
  else
    error("Neovim 0.10.0+ is required")
  end

  -- Check if plugin is loaded
  if vim.g.loaded_aibo then
    ok("Plugin is loaded")
  else
    warn("Plugin is not loaded. The plugin may not be installed correctly.")
  end

  -- Check configuration
  local aibo = require("aibo")
  local config = aibo.get_config()
  info(string.format("Submit delay: %dms", config.submit_delay or 100))
  info(string.format("Prompt height: %d lines", config.prompt_height or 10))

  -- Check AI agents
  start("AI Agents")

  local agents = {
    {
      name = "claude",
      desc = "Claude CLI",
      version_args = { "--version" },
      optional = true,
    },
    {
      name = "codex",
      desc = "Codex CLI",
      version_args = { "--version" },
      optional = true,
    },
    {
      name = "ollama",
      desc = "Ollama",
      version_args = { "--version" },
      optional = true,
    },
  }

  local found_any = false
  for _, agent in ipairs(agents) do
    if command_exists(agent.name) then
      found_any = true
      local version = get_command_version(agent.name, agent.version_args)
      if version then
        -- Extract first line of version output
        version = version:match("[^\n]+")
        ok(string.format("%s found: %s", agent.desc, version))
      else
        ok(string.format("%s found", agent.desc))
      end
    elseif not agent.optional then
      error(string.format("%s not found in PATH", agent.desc))
    end
  end

  if not found_any then
    warn("No AI agent CLI tools found. Install at least one AI agent CLI to use this plugin.")
    info("Supported agents: claude, codex, ollama")
  end

  -- Run integration-specific health checks
  local report = {
    start = start,
    ok = ok,
    warn = warn,
    error = error,
    info = info,
  }
  for _, tool in ipairs(aibo.integration.available_integrations()) do
    aibo.integration.check_health(tool, report)
  end

  -- Check terminal features
  start("Terminal Features")

  -- Check for color support
  local has_truecolor = vim.env.COLORTERM == "truecolor" or vim.env.COLORTERM == "24bit"
  local has_256color = vim.env.TERM and vim.env.TERM:match("256color")
  local termguicolors = vim.opt.termguicolors:get()

  if has_truecolor then
    ok("True color (24-bit) support detected")
    if not termguicolors then
      info("Consider setting 'termguicolors' for best color support")
    end
  elseif has_256color then
    ok("256 color support detected")
  else
    -- Check if Neovim detected color support
    local colors = vim.api.nvim_eval("&t_Co")
    if tonumber(colors) and tonumber(colors) >= 256 then
      ok(string.format("%s color support detected", colors))
    elseif termguicolors then
      ok("termguicolors is enabled")
    else
      info("Color support detection uncertain. Terminal should work fine if colors display correctly.")
    end
  end

  -- Check for special key support
  local special_keys = {
    ["<C-Enter>"] = "Control+Enter",
    ["<S-Tab>"] = "Shift+Tab",
    ["<F5>"] = "F5",
  }

  local unsupported = {}
  for key, desc in pairs(special_keys) do
    -- Try to get the terminal code for the key
    local code = vim.api.nvim_replace_termcodes(key, true, false, true)
    if code == key then
      -- Key was not translated, might not be supported
      table.insert(unsupported, desc)
    end
  end

  if #unsupported > 0 then
    info("Some special keys may not work in your terminal: " .. table.concat(unsupported, ", "))
    info("Consider using a modern terminal emulator like Kitty, WezTerm, or Ghostty")
  else
    ok("Terminal supports special key combinations")
  end

  -- Check ftplugin files
  start("Ftplugin Files")

  local ftplugins = {
    "aibo-prompt.lua",
    "aibo-console.lua",
    "aibo-tool-claude.lua",
    "aibo-tool-codex.lua",
  }

  local plugin_root = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
  if plugin_root then
    plugin_root = plugin_root:gsub("/lua/aibo/$", "")
    local all_found = true
    for _, file in ipairs(ftplugins) do
      local path = plugin_root .. "/ftplugin/" .. file
      if vim.fn.filereadable(path) == 1 then
        info(string.format("✓ %s", file))
      else
        all_found = false
        error(string.format("✗ %s not found", file))
      end
    end
    if all_found then
      ok("All ftplugin files found")
    end
  else
    warn("Could not determine plugin root directory")
  end

  -- Check core modules
  start("Core Modules")

  local core_modules = {
    { name = "aibo", desc = "Main module" },
    { name = "aibo.termcode", desc = "Termcode module" },
    { name = "aibo.command.aibo", desc = ":Aibo command" },
    { name = "aibo.command.aibo_send", desc = ":AiboSend command" },
  }

  local module_errors = 0
  for _, module in ipairs(core_modules) do
    local ok_mod, _ = pcall(require, module.name)
    if ok_mod then
      info(string.format("✓ %s", module.desc))
    else
      module_errors = module_errors + 1
      error(string.format("✗ %s (%s) failed to load", module.desc, module.name))
    end
  end

  if module_errors == 0 then
    ok("All core modules loaded successfully")
  else
    error(string.format("%d core modules failed to load", module_errors))
  end
end

return M
