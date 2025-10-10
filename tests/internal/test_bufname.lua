local eq = MiniTest.expect.equality
local helpers = require("tests.helpers")

local T = helpers.new_set()

-- Test encode_component function
T["encode_component escapes special characters"] = function()
  local bufname = require("aibo.internal.bufname")

  -- Space is converted to +
  eq(bufname.encode_component("hello world"), "hello+world")

  -- Special character escaping
  eq(bufname.encode_component("file<name>"), "file%3Cname%3E")
  eq(bufname.encode_component("file|name"), "file%7Cname")
  eq(bufname.encode_component("file?name"), "file%3Fname")
  eq(bufname.encode_component("file*name"), "file%2Aname")
  eq(bufname.encode_component("file/name"), "file%2Fname")
  eq(bufname.encode_component("file:name"), "file%3Aname")
  eq(bufname.encode_component("file+name"), "file%2Bname")

  -- Percent sign is escaped first
  eq(bufname.encode_component("file%name"), "file%25name")

  -- Multiple special characters
  eq(bufname.encode_component("hello world <test>"), "hello+world+%3Ctest%3E")
end

T["encode_component handles empty and normal strings"] = function()
  local bufname = require("aibo.internal.bufname")

  -- Empty string
  eq(bufname.encode_component(""), "")

  -- Normal strings (no escaping needed)
  eq(bufname.encode_component("filename"), "filename")
  eq(bufname.encode_component("file123"), "file123")
end

-- Test decode_component function
T["decode_component unescapes special characters"] = function()
  local bufname = require("aibo.internal.bufname")

  -- + is converted to space
  eq(bufname.decode_component("hello+world"), "hello world")

  -- Restore escaped special characters
  eq(bufname.decode_component("file%3Cname%3E"), "file<name>")
  eq(bufname.decode_component("file%7Cname"), "file|name")
  eq(bufname.decode_component("file%3Fname"), "file?name")
  eq(bufname.decode_component("file%2Aname"), "file*name")
  eq(bufname.decode_component("file%2Fname"), "file/name")
  eq(bufname.decode_component("file%3Aname"), "file:name")
  eq(bufname.decode_component("file%2Bname"), "file+name")

  -- Restore percent sign (processed last)
  eq(bufname.decode_component("file%25name"), "file%name")

  -- Multiple special characters
  eq(bufname.decode_component("hello+world+%3Ctest%3E"), "hello world <test>")
end

T["decode_component handles empty and normal strings"] = function()
  local bufname = require("aibo.internal.bufname")

  -- Empty string
  eq(bufname.decode_component(""), "")

  -- Normal strings
  eq(bufname.decode_component("filename"), "filename")
  eq(bufname.decode_component("file123"), "file123")
end

-- Test encode function
T["encode creates valid bufname with scheme"] = function()
  local bufname = require("aibo.internal.bufname")

  -- Basic encoding
  eq(bufname.encode("aibo", { "chat", "session1" }), "aibo://chat/session1")

  -- Empty component array
  eq(bufname.encode("aibo", {}), "aibo://")

  -- Single component
  eq(bufname.encode("scheme", { "component" }), "scheme://component")
end

T["encode handles special characters in components"] = function()
  local bufname = require("aibo.internal.bufname")

  -- Contains spaces
  eq(bufname.encode("aibo", { "chat session", "test" }), "aibo://chat+session/test")

  -- Multiple special characters
  eq(bufname.encode("aibo", { "chat<1>", "session?test" }), "aibo://chat%3C1%3E/session%3Ftest")

  -- Contains slash (must be distinguished from component separator)
  eq(bufname.encode("scheme", { "path/to/file" }), "scheme://path%2Fto%2Ffile")
end

T["encode handles multiple components"] = function()
  local bufname = require("aibo.internal.bufname")

  eq(bufname.encode("aibo", { "a", "b", "c" }), "aibo://a/b/c")
  eq(bufname.encode("scheme", { "part1", "part2", "part3", "part4" }), "scheme://part1/part2/part3/part4")
end

-- Test decode function
T["decode parses valid bufname"] = function()
  local bufname = require("aibo.internal.bufname")

  -- Basic decoding
  local scheme, components = bufname.decode("aibo://chat/session1")
  eq(scheme, "aibo")
  eq(#components, 2)
  eq(components[1], "chat")
  eq(components[2], "session1")
end

T["decode handles special characters in components"] = function()
  local bufname = require("aibo.internal.bufname")

  -- Spaces
  local scheme1, components1 = bufname.decode("aibo://chat+session/test")
  eq(scheme1, "aibo")
  eq(components1[1], "chat session")
  eq(components1[2], "test")

  -- Multiple special characters
  local scheme2, components2 = bufname.decode("aibo://chat%3C1%3E/session%3Ftest")
  eq(scheme2, "aibo")
  eq(components2[1], "chat<1>")
  eq(components2[2], "session?test")

  -- Slashes
  local scheme3, components3 = bufname.decode("scheme://path%2Fto%2Ffile")
  eq(scheme3, "scheme")
  eq(#components3, 1)
  eq(components3[1], "path/to/file")
end

T["decode handles edge cases"] = function()
  local bufname = require("aibo.internal.bufname")

  -- Scheme only
  local scheme1, components1 = bufname.decode("aibo://")
  eq(scheme1, "aibo")
  eq(#components1, 0)

  -- Single component
  local scheme2, components2 = bufname.decode("scheme://component")
  eq(scheme2, "scheme")
  eq(#components2, 1)
  eq(components2[1], "component")
end

T["decode handles invalid bufname"] = function()
  local bufname = require("aibo.internal.bufname")

  -- No scheme
  local scheme1, components1 = bufname.decode("invalid")
  eq(scheme1, nil)
  eq(#components1, 0)

  -- No separator
  local scheme2, components2 = bufname.decode("invalid:path")
  eq(scheme2, nil)
  eq(#components2, 0)

  -- Empty string
  local scheme3, components3 = bufname.decode("")
  eq(scheme3, nil)
  eq(#components3, 0)
end

-- Test encode/decode round-trip
T["encode and decode are reversible"] = function()
  local bufname = require("aibo.internal.bufname")

  local test_cases = {
    { scheme = "aibo", components = { "chat", "session1" } },
    { scheme = "aibo", components = { "chat session", "test file" } },
    { scheme = "scheme", components = { "path/to/file", "name<1>", "query?" } },
    { scheme = "test", components = { "a|b", "c*d", "e:f", "g+h" } },
    { scheme = "complex", components = { "Hello World", "Test<>?*|:/+%" } },
  }

  for _, test_case in ipairs(test_cases) do
    local encoded = bufname.encode(test_case.scheme, test_case.components)
    local scheme, components = bufname.decode(encoded)
    eq(scheme, test_case.scheme)
    eq(#components, #test_case.components)
    for i, comp in ipairs(test_case.components) do
      eq(components[i], comp)
    end
  end
end

T["component encode and decode are reversible"] = function()
  local bufname = require("aibo.internal.bufname")

  local test_strings = {
    "hello world",
    "file<name>",
    "path/to/file",
    "query?param",
    "wild*card",
    "pipe|separated",
    "colon:value",
    "plus+sign",
    "percent%sign",
    "complex <test>?with|many*special/chars:and+more%",
  }

  for _, str in ipairs(test_strings) do
    local encoded = bufname.encode_component(str)
    local decoded = bufname.decode_component(encoded)
    eq(decoded, str)
  end
end

return T
