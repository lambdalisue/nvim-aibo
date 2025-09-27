-- Tests for timing module (lua/aibo/internal/timing.lua)

local T = require("mini.test")

-- Test set
local test_set = T.new_set({
  hooks = {
    post_case = function()
      vim.cmd("silent! %bwipeout!")
      -- Ensure timers are cleaned up
      collectgarbage("collect")
    end,
  },
})

-- Debounce tests
test_set["debounce delays function execution"] = function()
  local timing = require("aibo.internal.timing")

  local called = false
  local value = nil
  local fn = timing.debounce(50, function(v)
    called = true
    value = v
  end)

  fn("test")
  T.expect.equality(called, false, "Function should not be called immediately")

  vim.wait(150, function()
    return called
  end)
  T.expect.equality(called, true, "Function should be called after delay")
  T.expect.equality(value, "test", "Function should receive correct argument")
end

test_set["debounce cancels previous timer on multiple calls"] = function()
  local timing = require("aibo.internal.timing")

  local call_count = 0
  local last_value = nil
  local fn = timing.debounce(50, function(v)
    call_count = call_count + 1
    last_value = v
  end)

  fn("first")
  fn("second")
  fn("third")

  vim.wait(150, function()
    return call_count > 0
  end)
  T.expect.equality(call_count, 1, "Function should only be called once")
  T.expect.equality(last_value, "third", "Function should receive last argument")
end

test_set["debounce handles multiple arguments"] = function()
  local timing = require("aibo.internal.timing")

  local args = nil
  local fn = timing.debounce(50, function(a, b, c)
    args = { a, b, c }
  end)

  fn("one", "two", "three")

  vim.wait(150, function()
    return args ~= nil
  end)
  T.expect.equality(args[1], "one", "First argument should be correct")
  T.expect.equality(args[2], "two", "Second argument should be correct")
  T.expect.equality(args[3], "three", "Third argument should be correct")
end

test_set["debounce creates independent functions"] = function()
  local timing = require("aibo.internal.timing")

  local count1 = 0
  local count2 = 0

  local fn1 = timing.debounce(50, function()
    count1 = count1 + 1
  end)

  local fn2 = timing.debounce(50, function()
    count2 = count2 + 1
  end)

  fn1()
  fn2()

  vim.wait(150, function()
    return count1 > 0 and count2 > 0
  end)
  T.expect.equality(count1, 1, "First function should be called once")
  T.expect.equality(count2, 1, "Second function should be called once")
end

test_set["debounce handles rapid successive calls"] = function()
  local timing = require("aibo.internal.timing")

  local call_count = 0
  local fn = timing.debounce(50, function()
    call_count = call_count + 1
  end)

  -- Rapid fire calls
  for i = 1, 10 do
    fn()
    vim.wait(10)
  end

  -- Wait for debounce to complete
  vim.wait(200, function()
    return call_count > 0
  end)
  T.expect.equality(call_count, 1, "Function should only be called once after rapid calls")
end

test_set["debounce executes after exact delay"] = function()
  local timing = require("aibo.internal.timing")

  local called = false
  local fn = timing.debounce(100, function()
    called = true
  end)

  fn()

  -- Should not be called before delay
  vim.wait(50)
  T.expect.equality(called, false, "Function should not be called before delay")

  -- Should be called after delay
  vim.wait(150, function()
    return called
  end)
  T.expect.equality(called, true, "Function should be called after delay")
end

test_set["debounce handles nil arguments"] = function()
  local timing = require("aibo.internal.timing")

  local args = nil
  local fn = timing.debounce(50, function(a, b)
    args = { a, b }
  end)

  fn(nil, "value")

  vim.wait(150, function()
    return args ~= nil
  end)
  T.expect.equality(args[1], nil, "First argument should be nil")
  T.expect.equality(args[2], "value", "Second argument should be correct")
end

test_set["debounce works with zero delay"] = function()
  local timing = require("aibo.internal.timing")

  local called = false
  local fn = timing.debounce(0, function()
    called = true
  end)

  fn()

  vim.wait(50, function()
    return called
  end)
  T.expect.equality(called, true, "Function should be called with zero delay")
end

-- Throttle tests
test_set["throttle executes immediately on first call"] = function()
  local timing = require("aibo.internal.timing")

  local called = false
  local fn = timing.throttle(100, function()
    called = true
  end)

  fn()
  T.expect.equality(called, true, "Function should execute immediately on first call")
end

test_set["throttle limits execution rate"] = function()
  local timing = require("aibo.internal.timing")

  local call_count = 0
  local fn = timing.throttle(100, function()
    call_count = call_count + 1
  end)

  -- First call executes immediately
  fn()
  T.expect.equality(call_count, 1, "First call should execute immediately")

  -- Second call should be throttled
  fn()
  T.expect.equality(call_count, 1, "Second call should be throttled")

  -- Wait for throttle period
  vim.wait(150, function()
    return call_count > 1
  end)

  -- Now it should execute the pending call
  T.expect.equality(call_count, 2, "Pending call should execute after throttle period")
end

test_set["throttle executes trailing call with latest arguments"] = function()
  local timing = require("aibo.internal.timing")

  local values = {}
  local fn = timing.throttle(100, function(v)
    table.insert(values, v)
  end)

  fn("first") -- Executes immediately
  fn("second") -- Throttled
  fn("third") -- Throttled, replaces "second"

  vim.wait(150, function()
    return #values >= 2
  end)
  T.expect.equality(#values, 2, "Should have two executions")
  T.expect.equality(values[1], "first", "First value should be from immediate execution")
  T.expect.equality(values[2], "third", "Second value should be from last throttled call")
end

test_set["throttle handles multiple arguments"] = function()
  local timing = require("aibo.internal.timing")

  local args = nil
  local fn = timing.throttle(50, function(a, b, c)
    args = { a, b, c }
  end)

  fn("one", "two", "three")
  T.expect.equality(args[1], "one", "First argument should be correct")
  T.expect.equality(args[2], "two", "Second argument should be correct")
  T.expect.equality(args[3], "three", "Third argument should be correct")
end

test_set["throttle creates independent functions"] = function()
  local timing = require("aibo.internal.timing")

  local count1 = 0
  local count2 = 0

  local fn1 = timing.throttle(50, function()
    count1 = count1 + 1
  end)

  local fn2 = timing.throttle(50, function()
    count2 = count2 + 1
  end)

  fn1()
  fn2()
  T.expect.equality(count1, 1, "First function should execute immediately")
  T.expect.equality(count2, 1, "Second function should execute immediately")

  fn1()
  fn2()
  T.expect.equality(count1, 1, "First function should be throttled")
  T.expect.equality(count2, 1, "Second function should be throttled")

  vim.wait(100, function()
    return count1 > 1 and count2 > 1
  end)
  T.expect.equality(count1, 2, "First function should execute pending call")
  T.expect.equality(count2, 2, "Second function should execute pending call")
end

test_set["throttle handles rapid successive calls"] = function()
  local timing = require("aibo.internal.timing")

  local call_count = 0
  local fn = timing.throttle(100, function()
    call_count = call_count + 1
  end)

  -- Rapid fire 10 calls over 200ms
  for i = 1, 10 do
    fn()
    vim.wait(20)
  end

  -- Should have executed: once immediately, once after 100ms, once after 200ms, and pending one
  vim.wait(150, function()
    return call_count >= 3
  end)
  -- With throttling at 100ms interval, we expect about 3-4 executions
  local is_in_range = call_count >= 3 and call_count <= 5
  T.expect.equality(is_in_range, true, string.format("Expected 3-4 executions, got %d", call_count))
end

test_set["throttle works with zero delay"] = function()
  local timing = require("aibo.internal.timing")

  local call_count = 0
  local fn = timing.throttle(0, function()
    call_count = call_count + 1
  end)

  fn()
  fn()
  fn()
  T.expect.equality(call_count, 3, "All calls should execute with zero delay")
end

test_set["throttle handles nil arguments"] = function()
  local timing = require("aibo.internal.timing")

  local args_list = {}
  local fn = timing.throttle(50, function(a, b)
    table.insert(args_list, { a, b })
  end)

  fn(nil, "value")
  T.expect.equality(#args_list, 1, "First call should execute")
  T.expect.equality(args_list[1][1], nil, "First argument should be nil")
  T.expect.equality(args_list[1][2], "value", "Second argument should be correct")

  fn("test", nil)
  vim.wait(100, function()
    return #args_list >= 2
  end)
  T.expect.equality(#args_list, 2, "Second call should execute after throttle")
  T.expect.equality(args_list[2][1], "test", "First argument should be correct")
  T.expect.equality(args_list[2][2], nil, "Second argument should be nil")
end

return test_set
