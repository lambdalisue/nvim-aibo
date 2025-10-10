local M = {}

---@param char string | number
function M.translate(char)
  local s = type(char) == "number" and vim.fn.nr2char(char) or char
  return vim.fn.keytrans(s)
end

---@param options? {prompt?: string, highlight?: string}
---@return string?
function M.get_single_keycode(options)
  options = options or {}
  local prompt = options.prompt
  local highlight = options.highlight or "MoreMsg"
  if prompt then
    vim.api.nvim_echo({ { prompt, highlight } }, false, {})
  end
  local ok, char = pcall(vim.fn.getchar)
  if prompt then
    vim.api.nvim_echo({}, false, {})
  end
  if ok and char then
    return M.translate(char)
  end
end

return M
