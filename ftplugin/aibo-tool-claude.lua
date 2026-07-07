if vim.b.loaded_aibo_agent_claude_ftplugin then
  return
end
vim.b.loaded_aibo_agent_claude_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()
local aibo = require("aibo")

-- Completion setup for Claude prompt buffers
-- Claude Code supports "@" file path references and "/" slash commands.
-- The completion logic lives in lua/aibo/completion/ (reusable modules);
-- trigger keymaps and autocmds are Claude-specific and set up here.
local bufname = vim.api.nvim_buf_get_name(bufnr)
local is_prompt = bufname:match("^aiboprompt://")
if is_prompt then
  require("aibo.completion.prompt_ftplugin").setup_completion(bufnr, "claude", "claude")
end

-- Default key mappings (unless disabled in config)
local cfg = aibo.get_tool_config("claude")
if not (cfg and cfg.no_default_mappings) then
  if is_prompt then
    require("aibo.completion.prompt_ftplugin").setup_triggers(bufnr)
  end

  local opts = { buffer = bufnr, nowait = true, silent = true }
  vim.keymap.set({ "n" }, "<Tab>", "<Plug>(aibo-send)<Tab>", opts)
  vim.keymap.set({ "n" }, "<S-Tab>", "<Plug>(aibo-send)<S-Tab>", opts)
  vim.keymap.set({ "n", "i" }, "<F2>", "<Plug>(aibo-send)<F2>", opts)
  vim.keymap.set({ "n" }, "<C-o>", "<Plug>(aibo-send)<C-o>", opts)
  vim.keymap.set({ "n" }, "<C-t>", "<Plug>(aibo-send)<C-t>", opts)
  vim.keymap.set({ "n" }, "<C-_>", "<Plug>(aibo-send)<C-_>", opts)
  vim.keymap.set({ "n" }, "<C-->", "<Plug>(aibo-send)<C-_>", opts)
  vim.keymap.set({ "n" }, "<Left>", "<Plug>(aibo-send)<Left>", opts)
  vim.keymap.set({ "n" }, "<Right>", "<Plug>(aibo-send)<Right>", opts)
  vim.keymap.set({ "i" }, "<C-v>", "<Plug>(aibo-send)<C-v>", opts)
  vim.keymap.set({ "i" }, "<C-u>", "<Plug>(aibo-send)<End><Plug>(aibo-send)<C-u>", opts)
end
