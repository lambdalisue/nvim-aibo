local M = {}

-- Encoding mappings (array format ensures order)
local ENCODE_CHARS = {
  { pattern = "%%", replacement = "%25" }, -- Process % first
  { pattern = "<", replacement = "%3C" },
  { pattern = ">", replacement = "%3E" },
  { pattern = "|", replacement = "%7C" },
  { pattern = "?", replacement = "%3F" },
  { pattern = "*", replacement = "%2A" },
  { pattern = "/", replacement = "%2F" },
  { pattern = ":", replacement = "%3A" },
  { pattern = "+", replacement = "%2B" },
  { pattern = " ", replacement = "+" }, -- Process space last
}

-- Decoding mappings (reverse order of encoding)
local DECODE_CHARS = {
  { pattern = "%+", replacement = " " }, -- Process space first
  { pattern = "%%2B", replacement = "+" },
  { pattern = "%%3A", replacement = ":" },
  { pattern = "%%2F", replacement = "/" },
  { pattern = "%%2A", replacement = "*" },
  { pattern = "%%3F", replacement = "?" },
  { pattern = "%%7C", replacement = "|" },
  { pattern = "%%3E", replacement = ">" },
  { pattern = "%%3C", replacement = "<" },
  { pattern = "%%25", replacement = "%" }, -- Process % last
}

---Encode a bufname with a scheme and components, escaping special characters (space, <, >, |, ?, *, %, /, :, +)
---@param scheme string
---@param components string[]
---@return string
function M.encode(scheme, components)
  local encoded_components = {}
  for _, comp in ipairs(components) do
    table.insert(encoded_components, M.encode_component(comp))
  end
  return scheme .. "://" .. table.concat(encoded_components, "/")
end

---Decode a bufname into its scheme and components, unescaping special characters (space, <, >, |, ?, *, %, /, :, +)
---@param bufname string
---@return string|nil scheme
---@return string[] components
function M.decode(bufname)
  local scheme, path = bufname:match("^(.-)://(.*)$")
  if not scheme or not path then
    return nil, {}
  end
  local components = {}
  for comp in path:gmatch("([^/]+)") do
    table.insert(components, M.decode_component(comp))
  end
  return scheme, components
end

---Encode a single component of a bufname, escaping special characters (space, <, >, |, ?, *, %, /, :, +)
---@param component string
---@return string
function M.encode_component(component)
  -- Process all characters sequentially in a single pass
  -- Use function form to avoid replacement string being interpreted as capture reference
  for _, mapping in ipairs(ENCODE_CHARS) do
    local replacement = mapping.replacement
    component = component:gsub(mapping.pattern, function()
      return replacement
    end)
  end
  return component
end

---Decode a single component of a bufname, unescaping special characters (space, <, >, |, ?, *, %, /, :, +)
---@param component string
---@return string
function M.decode_component(component)
  -- Process all characters sequentially in a single pass (reverse order of encoding)
  -- Use function form to avoid replacement string being interpreted as capture reference
  for _, mapping in ipairs(DECODE_CHARS) do
    local replacement = mapping.replacement
    component = component:gsub(mapping.pattern, function()
      return replacement
    end)
  end
  return component
end

return M
