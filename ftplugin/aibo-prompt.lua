if vim.b.loaded_aibo_prompt_ftplugin then
  return
end
vim.b.loaded_aibo_prompt_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()
local aibo = require("aibo")

-- Window settings (these apply to the current window)
vim.wo.number = false
vim.wo.relativenumber = false
vim.wo.signcolumn = "no"
vim.wo.winfixheight = true

-- Default key mappings (unless disabled in config)
local cfg = aibo.get_buffer_config("prompt")
if not (cfg and cfg.no_default_mappings) then
  vim.keymap.set("n", "<CR>", "<Plug>(aibo-prompt-submit)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<C-Enter>", "<Plug>(aibo-prompt-submit-close)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<F5>", "<Plug>(aibo-prompt-submit-close)", { buffer = bufnr, nowait = true })
  -- Don't map <Esc> to prevent unintended interrupts from Vimmer's habit of hitting Esc repeatedly
  -- Map <C-c> to send <Esc> instead
  vim.keymap.set({ "n", "i" }, "<C-c>", "<Plug>(aibo-prompt-esc)", { buffer = bufnr, nowait = true })
  -- g<C-c> sends the original <C-c> (interrupt signal)
  vim.keymap.set("n", "g<C-c>", "<Plug>(aibo-prompt-interrupt)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<C-l>", "<Plug>(aibo-prompt-clear)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<C-n>", "<Plug>(aibo-prompt-next)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<C-p>", "<Plug>(aibo-prompt-prev)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<Down>", "<Plug>(aibo-prompt-down)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<Up>", "<Plug>(aibo-prompt-up)", { buffer = bufnr, nowait = true })
  -- It seems <Esc> is required to properly close after submit
  vim.keymap.set("i", "<C-Enter>", "<Esc><Plug>(aibo-prompt-submit-close)", { buffer = bufnr, nowait = true })
  vim.keymap.set("i", "<F5>", "<Esc><Plug>(aibo-prompt-submit-close)", { buffer = bufnr, nowait = true })
end
