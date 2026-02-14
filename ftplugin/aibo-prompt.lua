if vim.b.loaded_aibo_prompt_ftplugin then
  return
end
vim.b.loaded_aibo_prompt_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()
local aibo = require("aibo")

-- Window settings (buffer-local, apply to all windows showing this buffer)
vim.opt_local.number = false
vim.opt_local.relativenumber = false
vim.opt_local.signcolumn = "no"
vim.opt_local.winfixheight = true

-- Default key mappings (unless disabled in config)
local cfg = aibo.get_buffer_config("prompt")
if not (cfg and cfg.no_default_mappings) then
  local opts = { buffer = bufnr, nowait = true, silent = true }
  vim.keymap.set({ "n", "i" }, "<C-g><C-o>", "<Plug>(aibo-send)", { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<CR>", "<Plug>(aibo-submit)", opts)
  vim.keymap.set("n", "<Esc>", "<Cmd>q<CR>", opts)
  vim.keymap.set("n", "<C-Enter>", "<Plug>(aibo-submit)<Cmd>q<CR>", opts)
  vim.keymap.set("n", "<F5>", "<Plug>(aibo-submit)<Cmd>q<CR>", opts)
  vim.keymap.set("i", "<C-Enter>", "<Esc><Plug>(aibo-submit)<Cmd>q<CR>", opts)
  vim.keymap.set("i", "<F5>", "<Esc><Plug>(aibo-submit)<Cmd>q<CR>", opts)
  vim.keymap.set("n", "<C-c>", "<Plug>(aibo-send)<Esc>", opts)
  vim.keymap.set("n", "g<C-c>", "<Plug>(aibo-send)<C-c>", opts)
  vim.keymap.set("n", "<C-l>", "<Plug>(aibo-send)<C-l>", opts)
  vim.keymap.set("n", "<C-n>", "<Plug>(aibo-send)<C-n>", opts)
  vim.keymap.set("n", "<C-p>", "<Plug>(aibo-send)<C-p>", opts)
  vim.keymap.set("n", "<Down>", "<Plug>(aibo-send)<Down>", opts)
  vim.keymap.set("n", "<Up>", "<Plug>(aibo-send)<Up>", opts)

  -- History navigation in insert mode (when completion menu is not visible)
  -- Uses feedkeys with explicit remap control to avoid infinite recursion:
  -- "n" flag = no remap (for built-in C-n/C-p in popup)
  -- "m" flag = remap (for <Plug> mapping expansion)
  vim.keymap.set("i", "<C-p>", function()
    if vim.fn.pumvisible() == 1 then
      local key = vim.api.nvim_replace_termcodes("<C-p>", true, false, true)
      vim.api.nvim_feedkeys(key, "n", false)
    else
      local key = vim.api.nvim_replace_termcodes("<Plug>(aibo-history-prev)", true, false, true)
      vim.api.nvim_feedkeys(key, "m", false)
    end
  end, { buffer = bufnr, silent = true })

  vim.keymap.set("i", "<C-n>", function()
    if vim.fn.pumvisible() == 1 then
      local key = vim.api.nvim_replace_termcodes("<C-n>", true, false, true)
      vim.api.nvim_feedkeys(key, "n", false)
    else
      local key = vim.api.nvim_replace_termcodes("<Plug>(aibo-history-next)", true, false, true)
      vim.api.nvim_feedkeys(key, "m", false)
    end
  end, { buffer = bufnr, silent = true })
end
