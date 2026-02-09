if vim.g.loaded_aibo then
  return
end
vim.g.loaded_aibo = 1

-- Check Neovim version (silently skip if not satisfied)
if vim.fn.has("nvim-0.10.0") ~= 1 then
  return
end

-- Define custom highlight groups for prompt window
local function setup_highlights()
  vim.api.nvim_set_hl(0, "AiboPromptNormal", { default = true, link = "Normal" })
  vim.api.nvim_set_hl(0, "AiboPromptBorder", { default = true, link = "FloatBorder" })
end

-- Setup highlights on startup
setup_highlights()

-- Re-setup highlights when colorscheme changes
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("aibo_highlights", { clear = true }),
  callback = setup_highlights,
})

-- Initialize command modules
require("aibo.command.aibo").setup()
require("aibo.command.aibo_send").setup()
