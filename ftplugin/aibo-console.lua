if vim.b.loaded_aibo_console_ftplugin then
  return
end
vim.b.loaded_aibo_console_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()
local aibo = require("aibo")

-- Window settings (these apply to the current window)
vim.wo.number = false
vim.wo.relativenumber = false
vim.wo.signcolumn = "no"

-- Avoid "Cannot make changes, 'modifiable' is off" errors on o/O
vim.keymap.set("n", "o", "i", { buffer = bufnr, desc = "Enter insert mode" })
vim.keymap.set("n", "O", "i", { buffer = bufnr, desc = "Enter insert mode" })

-- Default key mappings (unless disabled in config)
local cfg = aibo.get_buffer_config("console")
if not (cfg and cfg.no_default_mappings) then
  local opts = { buffer = bufnr, nowait = true, silent = true }
  vim.keymap.set("n", "<C-g><C-o>", "<Plug>(aibo-send)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<CR>", "<Plug>(aibo-submit)", opts)
  vim.keymap.set("n", "<C-Enter>", "<Plug>(aibo-submit)", opts)
  vim.keymap.set("n", "<F5>", "<Plug>(aibo-submit)", opts)
  vim.keymap.set("n", "<C-c>", "<Plug>(aibo-send)<Esc>", opts)
  vim.keymap.set("n", "g<C-c>", "<Plug>(aibo-send)<C-c>", opts)
  vim.keymap.set("n", "<C-l>", "<Plug>(aibo-send)<C-l>", opts)
  vim.keymap.set("n", "<C-n>", "<Plug>(aibo-send)<C-n>", opts)
  vim.keymap.set("n", "<C-p>", "<Plug>(aibo-send)<C-p>", opts)
  vim.keymap.set("n", "<Down>", "<Plug>(aibo-send)<Down>", opts)
  vim.keymap.set("n", "<Up>", "<Plug>(aibo-send)<Up>", opts)
end
