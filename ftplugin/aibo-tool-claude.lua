if vim.b.loaded_aibo_agent_claude_ftplugin then
  return
end
vim.b.loaded_aibo_agent_claude_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()
local aibo = require("aibo")

-- Default key mappings (unless disabled in config)
local cfg = aibo.get_tool_config("claude")
if not (cfg and cfg.no_default_mappings) then
  local opts = { buffer = bufnr, nowait = true, silent = true }
  vim.keymap.set({ "n", "i" }, "<Tab>", "<Plug>(aibo-send)<Tab>", opts)
  vim.keymap.set({ "n", "i" }, "<S-Tab>", "<Plug>(aibo-send)<S-Tab>", opts)
  vim.keymap.set({ "n", "i" }, "<F2>", "<Plug>(aibo-send)<F2>", opts)
  vim.keymap.set({ "n", "i" }, "<C-o>", "<Plug>(aibo-send)<C-o>", opts)
  vim.keymap.set({ "n", "i" }, "<C-t>", "<Plug>(aibo-send)<C-t>", opts)
  vim.keymap.set({ "n", "i" }, "<C-_>", "<Plug>(aibo-send)<C-_>", opts)
  vim.keymap.set({ "n", "i" }, "<C-->", "<Plug>(aibo-send)<C-_>", opts)
  vim.keymap.set({ "n", "i" }, "<C-v>", "<Plug>(aibo-send)<C-v>", opts)
  vim.keymap.set({ "n", "i" }, "<C-u>", "<Plug>(aibo-send)<End><Plug>(aibo-send)<C-u>", opts)
end
