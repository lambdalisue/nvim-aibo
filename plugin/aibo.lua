if vim.g.loaded_aibo then
  return
end
vim.g.loaded_aibo = 1

-- Check Neovim version (silently skip if not satisfied)
if vim.fn.has("nvim-0.10.0") ~= 1 then
  return
end

-- Initialize command modules
require("aibo.command.aibo").setup()
require("aibo.command.aibo_send").setup()
