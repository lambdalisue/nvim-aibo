local M = {}

---Create a debounced version of a function
---@param delay number Delay in milliseconds
---@param fn function The function to debounce
---@return function The debounced function
function M.debounce(delay, fn)
  local timer = nil

  return function(...)
    local args = { ... }

    -- Cancel existing timer if present
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end

    -- Create and start new timer
    timer = vim.loop.new_timer()
    timer:start(
      delay,
      0,
      vim.schedule_wrap(function()
        if timer then
          timer:stop()
          timer:close()
          timer = nil
        end
        fn(unpack(args))
      end)
    )
  end
end

---Create a throttled version of a function
---@param delay number Minimum time between executions in milliseconds
---@param fn function The function to throttle
---@return function The throttled function
function M.throttle(delay, fn)
  local timer = nil
  local last_time = 0
  local pending_args = nil

  return function(...)
    local args = { ... }
    local now = vim.loop.now()

    -- If enough time has passed, execute immediately
    if now - last_time >= delay then
      last_time = now
      fn(unpack(args))
      return
    end

    -- Store the latest arguments
    pending_args = args

    -- If no timer is running, start one
    if not timer then
      local remaining = delay - (now - last_time)
      timer = vim.loop.new_timer()
      timer:start(
        remaining,
        0,
        vim.schedule_wrap(function()
          if timer then
            timer:stop()
            timer:close()
            timer = nil
          end
          if pending_args then
            last_time = vim.loop.now()
            fn(unpack(pending_args))
            pending_args = nil
          end
        end)
      )
    end
  end
end

return M
