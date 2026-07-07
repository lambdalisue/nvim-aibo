if vim.b.loaded_aibo_agent_gemini_ftplugin then
  return
end
vim.b.loaded_aibo_agent_gemini_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()
local aibo = require("aibo")

-- Completion setup for Gemini prompt buffers
-- Gemini CLI supports "@" file path references and "/" slash commands.
-- The completion logic lives in lua/aibo/completion/ (reusable modules);
-- trigger keymaps and autocmds are Gemini-specific and set up here.
-- Gemini CLI speaks ACP natively, so this reads `tools.gemini.completion.acp`
-- (the generic ACP client's source key, not a Gemini-specific one) -- see
-- completion/acp.lua.
local bufname = vim.api.nvim_buf_get_name(bufnr)
local is_prompt = bufname:match("^aiboprompt://")
if is_prompt then
  require("aibo.completion.prompt_ftplugin").setup_completion(bufnr, "gemini", "gemini", "acp")
end

-- Default key mappings (unless disabled in config)
local cfg = aibo.get_tool_config("gemini")
if not (cfg and cfg.no_default_mappings) then
  if is_prompt then
    require("aibo.completion.prompt_ftplugin").setup_triggers(bufnr)
  end
end
