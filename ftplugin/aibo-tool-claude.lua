if vim.b.loaded_aibo_agent_claude_ftplugin then
  return
end
vim.b.loaded_aibo_agent_claude_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()
local aibo = require("aibo")

-- Default key mappings (unless disabled in config)
local cfg = aibo.get_tool_config("claude")
if not (cfg and cfg.no_default_mappings) then
  vim.keymap.set({ "n", "i" }, "<S-Tab>", "<Plug>(aibo-claude-mode)", { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<F2>", "<Plug>(aibo-claude-mode)", { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<C-o>", "<Plug>(aibo-claude-verbose)", { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<C-t>", "<Plug>(aibo-claude-todo)", { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<C-_>", "<Plug>(aibo-claude-undo)", { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<C-->", "<Plug>(aibo-claude-undo)", { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<C-v>", "<Plug>(aibo-claude-paste)", { buffer = bufnr })
  vim.keymap.set("n", "?", "<Plug>(aibo-claude-shortcuts)", { buffer = bufnr })
  vim.keymap.set("n", "!", "<Plug>(aibo-claude-bash-mode)", { buffer = bufnr })
  vim.keymap.set("n", "#", "<Plug>(aibo-claude-memorize)", { buffer = bufnr })
end

