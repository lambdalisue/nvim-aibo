if vim.g.loaded_aibo then
  return
end
vim.g.loaded_aibo = 1

-- Check Neovim version (silently skip if not satisfied)
if vim.fn.has("nvim-0.10.0") ~= 1 then
  return
end

-- Prevent prompt buffer from being opened in non-floating windows
vim.api.nvim_create_autocmd("WinNew", {
  group = vim.api.nvim_create_augroup("aibo_prompt_winnew", { clear = true }),
  pattern = "aiboprompt://*",
  callback = function()
    -- Capture winid synchronously before scheduling
    local winid = vim.api.nvim_get_current_win()
    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(winid) then
        return
      end

      local win_config = vim.api.nvim_win_get_config(winid)
      -- Close if not a floating window
      if win_config.relative == "" then
        vim.api.nvim_win_close(winid, true)
        vim.notify("Prompt buffer cannot be split", vim.log.levels.WARN, { title = "Aibo prompt" })
      end
    end)
  end,
})

-- Initialize command modules
require("aibo.command.aibo").setup()
require("aibo.command.aibo_send").setup()
