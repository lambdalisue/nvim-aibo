if vim.b.loaded_aibo_agent_codex_ftplugin then
  return
end
vim.b.loaded_aibo_agent_codex_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()
local aibo = require("aibo")

-- Default key mappings (unless disabled in config)
local cfg = aibo.get_tool_config("codex")
if not (cfg and cfg.no_default_mappings) then
  vim.keymap.set({ "n", "i" }, "<C-t>", "<Plug>(aibo-codex-transcript)", { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<Home>", "<Plug>(aibo-codex-home)", { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<End>", "<Plug>(aibo-codex-end)", { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<PageUp>", "<Plug>(aibo-codex-page-up)", { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<PageDown>", "<Plug>(aibo-codex-page-down)", { buffer = bufnr })
  vim.keymap.set({ "n" }, "q", "<Plug>(aibo-codex-quit)", { buffer = bufnr })
end

