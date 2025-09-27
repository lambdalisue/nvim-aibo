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
  vim.keymap.set("n", "<CR>", "<Plug>(aibo-console-submit)", { buffer = bufnr, nowait = true })
  -- Don't map <Esc> to prevent unintended interrupts from Vimmer's habit of hitting Esc repeatedly
  -- Map <C-c> to send <Esc> instead
  vim.keymap.set({ "n", "i" }, "<C-c>", "<Plug>(aibo-console-esc)", { buffer = bufnr, nowait = true })
  -- g<C-c> sends the original <C-c> (interrupt signal)
  vim.keymap.set("n", "g<C-c>", "<Plug>(aibo-console-interrupt)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<C-l>", "<Plug>(aibo-console-clear)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<C-n>", "<Plug>(aibo-console-next)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<C-p>", "<Plug>(aibo-console-prev)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<Down>", "<Plug>(aibo-console-down)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<Up>", "<Plug>(aibo-console-up)", { buffer = bufnr, nowait = true })
end

