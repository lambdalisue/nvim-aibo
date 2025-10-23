if vim.b.loaded_aibo_agent_codex_ftplugin then
  return
end
vim.b.loaded_aibo_agent_codex_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()
local aibo = require("aibo")

-- Default key mappings (unless disabled in config)
local cfg = aibo.get_tool_config("codex")
if not (cfg and cfg.no_default_mappings) then
  local opts = { buffer = bufnr, nowait = true, silent = true }
  vim.keymap.set({ "n", "i" }, "<C-t>", "<Plug>(aibo-send)<C-t>", opts)
  vim.keymap.set({ "n", "i" }, "<C-v>", "<Plug>(aibo-send)<C-v>", opts)
  vim.keymap.set({ "n", "i" }, "<C-u>", "<Plug>(aibo-send)<End><Plug>(aibo-send)<C-u>", opts)
  vim.keymap.set({ "n", "i" }, "<Home>", "<Plug>(aibo-send)<Home>", opts)
  vim.keymap.set({ "n", "i" }, "<End>", "<Plug>(aibo-send)<End>", opts)
  vim.keymap.set({ "n", "i" }, "<PageUp>", "<Plug>(aibo-send)<PageUp>", opts)
  vim.keymap.set({ "n", "i" }, "<PageDown>", "<Plug>(aibo-send)<PageDown>", opts)
end
