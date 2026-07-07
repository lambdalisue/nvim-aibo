--- Shared prompt-buffer completion wiring for tool ftplugins
--- (ftplugin/aibo-tool-*.lua): sets the omnifunc/completeopt, warms the live
--- probe cache per `tools.<tool_name>.completion.<source>`, and wires the
--- "/" and "@" auto-trigger keymaps. Each ftplugin still owns its own
--- tool-specific key mappings (send keys etc.) and the `no_default_mappings`
--- gate around them.
local M = {}

local file_completion = require("aibo.completion.file")

---Set the omnifunc and warm the live-probed completion cache for a prompt
---buffer. Enabled by default (`tools.<tool_name>.completion.<source>`); set
---it to `false` to disable "/" completion for this tool entirely -- there is
---no static fallback. No prompt is ever sent to the agent (no tokens).
---@param bufnr integer
---@param module_name string Completion submodule name, e.g. "claude" (aibo.completion.<module_name>)
---@param tool_name string Tool name aibo dispatches on, e.g. "claude" (`tools.<tool_name>` in AiboConfig)
---@param source? string Completion source key under `tools.<tool_name>.completion` (defaults to `module_name`; e.g. "gemini" tool uses module "gemini" but source "acp")
function M.setup_completion(bufnr, module_name, tool_name, source)
  local aibo = require("aibo")
  local completion = require("aibo.completion." .. module_name)

  vim.bo[bufnr].omnifunc = ("v:lua.require'aibo.completion.%s'.omnifunc"):format(module_name)
  vim.opt_local.completeopt:append("menuone")
  vim.opt_local.completeopt:append("noselect")

  local probe_cfg = aibo.get_completion_config(tool_name, source or module_name)
  if probe_cfg then
    -- `true` means "enable with defaults"; a table carries overrides.
    local cfg = type(probe_cfg) == "table" and probe_cfg or {}
    -- Probe once per cwd: reopening another prompt buffer in the same
    -- directory reuses the warm cache instead of respawning the agent.
    if not completion.get_cached() then
      completion.refresh_acp({ cmd = cfg.cmd, timeout = cfg.timeout })
    end
  end
end

---Wire the "/" and "@" auto-trigger keymaps for a prompt buffer.
---@param bufnr integer
function M.setup_triggers(bufnr)
  local controller = file_completion.setup_auto_completion(bufnr)

  -- Auto-trigger @ file path completion when "@" is typed at start of
  -- line or after whitespace. Insert "@" and let TextChangedI show popup.
  vim.keymap.set("i", "@", function()
    local line = vim.api.nvim_get_current_line()
    local col = vim.fn.col(".")
    local before = line:sub(1, col - 1)
    if before == "" or before:match("%s$") then
      controller.activate()
    end
    return "@"
  end, { buffer = bufnr, expr = true, silent = true })

  -- Auto-trigger completion when "/" is typed:
  --   1. At start of line or after whitespace -> slash command completion
  --      (uses <C-x><C-o> omnifunc — separate from @ completion system)
  --   2. Within an @ path -> insert "/" and let TextChanged show popup
  vim.keymap.set("i", "/", function()
    local line = vim.api.nvim_get_current_line()
    local col = vim.fn.col(".")
    local before = line:sub(1, col - 1)
    -- Slash command trigger (separate system, uses omnifunc)
    if before == "" or before:match("%s$") then
      return "/<C-x><C-o>"
    end
    -- @ file path handling
    local action = file_completion.handle_slash_key(line, col)
    if action == "trigger" then
      controller.activate()
      vim.schedule(function()
        controller.show()
      end)
      return ""
    end
    if action == "insert_and_trigger" then
      controller.activate()
      return "/"
    end
    return "/"
  end, { buffer = bufnr, expr = true, silent = true })
end

return M
