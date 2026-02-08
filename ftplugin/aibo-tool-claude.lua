if vim.b.loaded_aibo_agent_claude_ftplugin then
  return
end
vim.b.loaded_aibo_agent_claude_ftplugin = true

local bufnr = vim.api.nvim_get_current_buf()
local aibo = require("aibo")

-- Set up omnifunc for slash command completion (only for prompt buffers)
local bufname = vim.api.nvim_buf_get_name(bufnr)
local is_prompt = bufname:match("^aiboprompt://")
if is_prompt then
  vim.bo[bufnr].omnifunc = "v:lua.require'aibo.completion.claude'.omnifunc"
  -- Ensure completion menu doesn't auto-select first item
  vim.opt_local.completeopt:append("noselect")
end

-- Default key mappings (unless disabled in config)
local cfg = aibo.get_tool_config("claude")
if not (cfg and cfg.no_default_mappings) then
  -- Auto-trigger slash command completion when "/" is typed at start of line or after whitespace
  if is_prompt then
    vim.keymap.set("i", "/", function()
      local line = vim.api.nvim_get_current_line()
      local col = vim.fn.col(".")
      local before = line:sub(1, col - 1)
      -- Trigger completion if "/" is at start of line or after whitespace
      if before == "" or before:match("%s$") then
        return "/<C-x><C-o>"
      end
      return "/"
    end, { buffer = bufnr, expr = true, silent = true })
  end
  local opts = { buffer = bufnr, nowait = true, silent = true }
  vim.keymap.set({ "n" }, "<Tab>", "<Plug>(aibo-send)<Tab>", opts)
  vim.keymap.set({ "n" }, "<S-Tab>", "<Plug>(aibo-send)<S-Tab>", opts)
  vim.keymap.set({ "n", "i" }, "<F2>", "<Plug>(aibo-send)<F2>", opts)
  vim.keymap.set({ "n" }, "<C-o>", "<Plug>(aibo-send)<C-o>", opts)
  vim.keymap.set({ "n" }, "<C-t>", "<Plug>(aibo-send)<C-t>", opts)
  vim.keymap.set({ "n" }, "<C-_>", "<Plug>(aibo-send)<C-_>", opts)
  vim.keymap.set({ "n" }, "<C-->", "<Plug>(aibo-send)<C-_>", opts)
  vim.keymap.set({ "n" }, "<Left>", "<Plug>(aibo-send)<Left>", opts)
  vim.keymap.set({ "n" }, "<Right>", "<Plug>(aibo-send)<Right>", opts)
  vim.keymap.set({ "i" }, "<C-v>", "<Plug>(aibo-send)<C-v>", opts)
  vim.keymap.set({ "i" }, "<C-u>", "<Plug>(aibo-send)<End><Plug>(aibo-send)<C-u>", opts)
end
