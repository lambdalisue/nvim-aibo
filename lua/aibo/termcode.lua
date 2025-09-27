local M = {}

-- Why we need a custom implementation instead of nvim_replace_termcodes:
-- vim.api.nvim_replace_termcodes returns key codes for Neovim's internal use,
-- which differ from the actual escape sequences that terminal programs expect.
--
-- Examples of the difference:
--   Key     nvim_replace_termcodes           termcode.resolve
--   <Up>    "\x80\x6B\x75" (0x80 0x6B 0x75)  "\27[A" (0x1B 0x5B 0x41)
--   <Down>  "\x80\x6B\x64" (0x80 0x6B 0x64)  "\27[B" (0x1B 0x5B 0x42)
--   <Home>  "\x80\x6B\x68" (0x80 0x6B 0x68)  "\27[H" (0x1B 0x5B 0x48)
--   <C-A>   "\x01"         (0x01)            "\x01"  (0x01)
--   <CR>    "\x0D"         (0x0D)            "\x0D"  (0x0D)
--
-- Neovim uses 0x80-prefixed sequences for special keys internally,
-- while terminals expect standard ANSI escape sequences (ESC [ ...).
-- When sending input to terminal programs, we need the latter format.

-- Key definitions: type and parameters for building escape sequences
-- Types:
--   csi: ESC [ char (or ESC [ 1 ; mod char with modifiers)
--   ss3: ESC O char (or ESC [ 1 ; mod char with modifiers)
--   param: ESC [ n ~ (or ESC [ n ; mod ~ with modifiers)
--   char: Direct character (no escape sequence)
local keys = {
  -- Navigation (CSI format)
  up = { type = "csi", char = "A" },
  down = { type = "csi", char = "B" },
  right = { type = "csi", char = "C" },
  left = { type = "csi", char = "D" },
  home = { type = "csi", char = "H" },
  ["end"] = { type = "csi", char = "F" },

  -- Page/Edit (parameter format)
  pageup = { type = "param", code = "5" },
  pagedown = { type = "param", code = "6" },
  insert = { type = "param", code = "2" },
  delete = { type = "param", code = "3" },

  -- Function keys F1-F4 (SS3 format)
  f1 = { type = "ss3", char = "P" },
  f2 = { type = "ss3", char = "Q" },
  f3 = { type = "ss3", char = "R" },
  f4 = { type = "ss3", char = "S" },

  -- Function keys F5-F12 (parameter format)
  f5 = { type = "param", code = "15" },
  f6 = { type = "param", code = "17" },
  f7 = { type = "param", code = "18" },
  f8 = { type = "param", code = "19" },
  f9 = { type = "param", code = "20" },
  f10 = { type = "param", code = "21" },
  f11 = { type = "param", code = "23" },
  f12 = { type = "param", code = "24" },

  -- Control characters
  esc = { type = "char", char = "\27" },
  escape = { type = "char", char = "\27" },
  tab = { type = "char", char = "\9" },
  cr = { type = "char", char = "\13" },
  enter = { type = "char", char = "\13" },
  ["return"] = { type = "char", char = "\13" },
  bs = { type = "char", char = "\127" },
  backspace = { type = "char", char = "\127" },
  space = { type = "char", char = " " },

  -- Special characters
  lt = { type = "char", char = "<" },
  gt = { type = "char", char = ">" },
  bar = { type = "char", char = "|" },
  bslash = { type = "char", char = "\\" },
}

-- Modifier codes
local modifiers = {
  S = 2, -- Shift
  A = 3, -- Alt
  M = 3, -- Meta (same as Alt)
  AS = 4, -- Alt+Shift
  C = 5, -- Ctrl
  CS = 6, -- Ctrl+Shift
  CA = 7, -- Ctrl+Alt
  CAS = 8, -- Ctrl+Alt+Shift
}

--- Parse a key string like "C-S-Up" into modifier and key parts
local function parse_key(str)
  local mod_str = ""
  local key = str

  if str:match("%-") then
    -- Collect modifiers in canonical order: C, A/M, S (case-insensitive)
    local has_c = str:match("[Cc]%-")
    local has_a = str:match("[AaMm]%-")
    local has_s = str:match("[Ss]%-")

    if has_c then
      mod_str = mod_str .. "C"
    end
    if has_a then
      mod_str = mod_str .. "A"
    end
    if has_s then
      mod_str = mod_str .. "S"
    end

    -- Extract the key after the last dash
    key = str:match("%-([^%-]+)$") or str
  end

  return mod_str, key:lower()
end

--- Build escape sequence for a key with optional modifiers
local function build_sequence(key, mod)
  -- Handle Ctrl+letter (produces control characters directly)
  if mod == "C" and #key == 1 then
    local byte = string.byte(key)
    if byte >= 97 and byte <= 122 then -- a-z
      return string.char(byte - 96)
    elseif byte >= 64 and byte <= 95 then -- @, [, \, ], ^, _
      return string.char(byte - 64)
    end
  end

  -- Get key definition
  local def = keys[key]
  if not def then
    return nil
  end

  -- Get modifier code
  local mod_code = modifiers[mod] or 0

  -- Build sequence based on type
  if def.type == "char" then
    -- Direct character - no escape sequence
    return def.char
  elseif def.type == "csi" then
    -- CSI format: ESC [ char or ESC [ 1 ; mod char
    if mod == "" then
      return "\27[" .. def.char
    else
      return string.format("\27[1;%d%s", mod_code, def.char)
    end
  elseif def.type == "ss3" then
    -- SS3 format: ESC O char (unmodified) or ESC [ 1 ; mod char (modified)
    if mod == "" then
      return "\27O" .. def.char
    else
      return string.format("\27[1;%d%s", mod_code, def.char)
    end
  elseif def.type == "param" then
    -- Parameter format: ESC [ n ~ or ESC [ n ; mod ~
    if mod == "" then
      return "\27[" .. def.code .. "~"
    else
      return string.format("\27[%s;%d~", def.code, mod_code)
    end
  end

  return nil
end

--- Resolve Vim-style key notation to terminal escape sequences
--- @param input string Key notation like "<Up>", "<C-A>", "<S-F5>", "<Up><Down>"
--- @return string|nil Terminal escape sequence, or nil if unable to resolve
function M.resolve(input)
  if not input or input == "" then
    return nil
  end

  local result = {}
  local i = 1

  while i <= #input do
    local char = input:sub(i, i)

    if char == "<" then
      -- Find closing bracket
      local j = input:find(">", i + 1)
      if j then
        -- Parse key notation
        local key_str = input:sub(i + 1, j - 1)
        local mod_str, key = parse_key(key_str)

        -- Build escape sequence
        local seq = build_sequence(key, mod_str)
        if seq then
          table.insert(result, seq)
        elseif #key == 1 then
          -- Single character without mapping - use literally
          table.insert(result, key)
        else
          return nil -- Unknown key
        end

        i = j + 1
      else
        -- No closing bracket - treat as literal
        table.insert(result, char)
        i = i + 1
      end
    else
      -- Regular character
      table.insert(result, char)
      i = i + 1
    end
  end

  return table.concat(result)
end

return M
