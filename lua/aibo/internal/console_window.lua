local M = {}
local PREFIX = "aiboconsole"

---@alias JobInfo { cmd: string, args: string[], job_id: number }
---@alias ConsoleInfo { winid: number, bufnr: number, bufname: string, jobinfo: JobInfo }

---@param bufname string Buffer name to parse
---@return JobInfo?
local function parse_bufname(bufname)
  local bufname_module = require("aibo.internal.bufname")
  local scheme, components = bufname_module.decode(bufname)
  if scheme ~= PREFIX then
    return nil
  end
  -- Note: bufname.decode skips empty components, so:
  -- "aiboconsole://cmd//job_id" → ["cmd", "job_id"]
  -- "aiboconsole://cmd/args/job_id" → ["cmd", "args", "job_id"]
  local cmd = components[1] or ""
  local args = {}
  local job_id = nil

  if #components == 2 then
    -- No args, only cmd and job_id
    job_id = tonumber(components[2])
  elseif #components >= 3 then
    -- Has args: cmd, args, job_id
    if components[2] and components[2] ~= "" then
      -- Split by space (which was originally + before decode_component converted it)
      local parts = vim.split(components[2], " ")
      -- Filter out empty strings
      for _, part in ipairs(parts) do
        if part ~= "" then
          table.insert(args, part)
        end
      end
    end
    job_id = tonumber(components[3])
  end

  return {
    cmd = cmd,
    args = args,
    job_id = job_id,
  }
end

---@param partial { winid?: number, bufnr?: number, bufname?: string }
---@return ConsoleInfo? Complete info or nil if invalid
local function build_info(partial)
  local winid = partial.winid
  local bufnr = partial.bufnr
  local bufname
  if winid then
    if not vim.api.nvim_win_is_valid(winid) then
      return nil
    end
    bufnr = bufnr or vim.api.nvim_win_get_buf(winid)
    bufname = partial.bufname or vim.api.nvim_buf_get_name(bufnr)
  elseif bufnr then
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return nil
    end
    winid = winid or vim.fn.bufwinid(bufnr)
    bufname = partial.bufname or vim.api.nvim_buf_get_name(bufnr)
  else
    error("[aibo] Either winid or bufnr must be provided")
  end
  local bufname_module = require("aibo.internal.bufname")
  local scheme, _ = bufname_module.decode(bufname)
  if scheme ~= PREFIX then
    return nil
  end
  local jobinfo = parse_bufname(bufname)
  return {
    winid = winid,
    bufnr = bufnr,
    bufname = bufname,
    jobinfo = jobinfo,
  }
end

---@param bufnr number Buffer number to set mappings for
local function setup_mappings(bufnr)
  local aibo = require("aibo")

  local define = function(lhs, desc, rhs)
    vim.keymap.set({ "n", "i" }, lhs, rhs, {
      buffer = bufnr,
      desc = desc,
      silent = true,
    })
  end

  local send = function(key)
    local winid = vim.api.nvim_get_current_win()
    local info = M.get_info_by_winid(winid)
    if info and info.bufnr then
      local code = aibo.resolve(key) or key
      M.send(info.bufnr, code)
    end
  end

  local submit = function(key)
    local winid = vim.api.nvim_get_current_win()
    local info = M.get_info_by_winid(winid)
    if info and info.bufnr then
      local code = aibo.resolve(key) or key
      M.submit(info.bufnr, code)
    end
  end

  define("<Plug>(aibo-send)", "Get one key from user and send it to the tool", function()
    local keycode = require("aibo.internal.keycode")
    local key = keycode.get_single_keycode({ prompt = "Oneshot (press any key): ", highlight = "MoreMsg" })
    if key then
      send(key)
    end
  end)
  define("<Plug>(aibo-submit)", "Submit to the tool", function()
    submit("")
  end)
end

local function BufWinEnter()
  local prompt = require("aibo.internal.prompt_window")
  -- We need to use nvim_get_current_win() because bufwinid() may return wrong winid
  -- if multiple windows show the same buffer (e.g. :split)
  local winid = vim.api.nvim_get_current_win()
  local info = M.get_info_by_winid(winid)
  vim.defer_fn(function()
    if info and vim.api.nvim_win_is_valid(info.winid) then
      prompt.open(info.winid)
    end
  end, 0)
end

local function TermEnter()
  local aibo = require("aibo")
  local prompt = require("aibo.internal.prompt_window")
  -- We need to use nvim_get_current_win() because bufwinid() may return wrong winid
  -- if multiple windows show the same buffer (e.g. :split)
  local winid = vim.api.nvim_get_current_win()
  local config = aibo.get_config()
  prompt.open(winid, {
    startinsert = not config.disable_startinsert_on_insert,
  })
end

---@param ev { buf: number, file: string } Event data
local function WinClosed(ev)
  local prompt = require("aibo.internal.prompt_window")
  local winid = tonumber(vim.fn.expand(ev.file))
  if not winid then
    return
  end
  local info = prompt.get_info_by_console_winid(winid)
  if info then
    -- To avoid "E855: Autocommands caused command to abort"
    vim.defer_fn(function()
      if vim.api.nvim_win_is_valid(info.winid) then
        -- To quit if the prompt window is the last window, we use quit command
        -- instead of vim.api.nvim_win_close()
        vim.api.nvim_win_call(info.winid, function()
          vim.cmd("quit")
        end)
      end
    end, 0)
  end
end

--- Get console information by buffer number.
--- Retrieves complete information about a console buffer including its window,
--- job details, and associated command.
---
--- @param bufnr number The buffer number to query
--- @return ConsoleInfo?
---
--- @usage
---   local console = require("aibo.internal.console_window")
---   local info = console.get_info_by_bufnr(vim.api.nvim_get_current_buf())
---   if info and info.jobinfo then
---     print("Console running: " .. info.jobinfo.cmd)
---   end
function M.get_info_by_bufnr(bufnr)
  return build_info({ bufnr = bufnr })
end

--- Get console information by window ID.
--- Retrieves complete information about a console displayed in a specific window.
---
--- @param winid number The window ID to query
--- @return ConsoleInfo?
---
--- @usage
---   local console = require("aibo.internal.console_window")
---   local info = console.get_info_by_winid(vim.api.nvim_get_current_win())
---   if info then
---     console.send(info.bufnr, "ls -la\n")
---   end
function M.get_info_by_winid(winid)
  return build_info({ winid = winid })
end

---@param options? { cmd?: string, args?: string[] }
---@return ConsoleInfo?
function M.find_info_in_tabpage(options)
  options = options or {}

  local cmd = options.cmd
  local args = options.args

  local founds = {}
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local info = M.get_info_by_winid(winid)
    if info and info.jobinfo then
      -- cmd matches if not specified or equals
      local cmd_matches = not cmd or info.jobinfo.cmd == cmd
      -- args matches if not specified or equals
      local args_matches = not args or vim.deep_equal(info.jobinfo.args, args)
      if cmd_matches and args_matches then
        table.insert(founds, info)
      end
    end
  end

  -- Early return conditions
  if not founds or #founds == 0 then
    return nil
  elseif #founds == 1 then
    return founds[1]
  end

  -- Use synchronous inputlist since vim.ui.select is asynchronous
  local choices = { "Multiple Aibo console windows found. Select one:" }
  for i, v in ipairs(founds) do
    choices[#choices + 1] = string.format("%d. %s (bufnr: %d, winid: %d)", i, v.bufname, v.bufnr, v.winid)
  end
  local idx = vim.fn.inputlist(choices)
  if idx >= 1 and idx <= #founds then
    return founds[idx]
  end
  return nil
end

--- Open a new console window and start an agent process.
--- Creates a terminal buffer, executes the specified command, and sets up
--- all necessary autocmds, mappings, and callbacks.
---
--- @param cmd string The command to execute (e.g., "claude", "codex")
--- @param args? string[] Optional command arguments
--- @param options? table Optional configuration:
---   - opener?: string - Window command ("split", "vsplit", "tabnew", etc.)
---                       Default: "edit" (replaced with "enew" internally)
--- @return ConsoleInfo?
---
--- @usage
---   local console = require("aibo.internal.console_window")
---   -- Open aider in a vertical split
---   local info = console.open("claude", {"--continue"}, {
---     opener = "vsplit",
---     on_exit = function(winid, bufnr)
---       print("Claude session ended")
---     end
---   })
function M.open(cmd, args, options)
  local aibo = require("aibo")
  local prompt = require("aibo.internal.prompt_window")

  args = args or {}
  options = options or {}

  -- We need to skip "edit" while Scratch buffer failed to execute the command
  local opener = string.gsub(options.opener or "", "edit", "")
  if opener ~= "" then
    vim.cmd(string.format("silent %s", opener))
  end

  -- Create a new empty buffer to open the terminal in
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)

  local winid = vim.api.nvim_get_current_win()
  local job_cmd = vim.list_extend({ cmd }, args)
  local job_id = vim.fn.jobstart(job_cmd, { term = true })
  bufnr = vim.api.nvim_get_current_buf()

  if job_id <= 0 then
    vim.notify(
      string.format("Failed to start terminal job: %s %s", cmd, table.concat(args, " ")),
      vim.log.levels.ERROR,
      { title = "Aibo console Error" }
    )
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return nil
  end
  vim.cmd("stopinsert")

  local bufname_module = require("aibo.internal.bufname")
  -- Join args with space, which will be encoded as + by encode_component
  local args_component = table.concat(args, " ")
  local bufname = bufname_module.encode(PREFIX, { cmd, args_component, tostring(job_id) })
  vim.api.nvim_buf_set_name(bufnr, bufname)

  setup_mappings(bufnr)
  vim.b[bufnr].terminal_job_id = job_id
  vim.bo[bufnr].filetype = string.format("aibo-console.aibo-tool-%s", cmd)

  -- WinClosed pattern is matched against window ID so we cannot use global one
  local augroup = vim.api.nvim_create_augroup(string.format("aibo_console_internal_open_%d", bufnr), { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    buffer = bufnr,
    nested = true,
    callback = WinClosed,
  })

  local info = {
    type = "console",
    cmd = cmd,
    args = args,
    job_id = job_id,
  }
  local buffer_cfg = aibo.get_buffer_config("console")
  if buffer_cfg.on_attach then
    buffer_cfg.on_attach(bufnr, info)
  end
  local tool_cfg = aibo.get_tool_config(cmd)
  if tool_cfg.on_attach then
    tool_cfg.on_attach(bufnr, info)
  end

  local config = aibo.get_config()

  -- Open an associated prompt window with insert mode
  prompt.open(winid, {
    startinsert = not config.disable_startinsert_on_startup,
  })

  return {
    winid = winid,
    bufnr = bufnr,
    bufname = bufname,
    jobinfo = {
      cmd = cmd,
      args = args,
      job_id = job_id,
    },
  }
end

--- Focus existing console or create a new one if none exists.
--- This ensures only one instance of a specific agent is running.
--- If a matching console exists but is not visible, it will be displayed.
--- If it's already visible, focus will be moved to it.
---
--- @param cmd string The command to execute (e.g., "claude", "codex")
--- @param args? string[] Optional command arguments
--- @param options? table Optional configuration (same as M.open):
---   - opener?: string - Window command for displaying hidden console
---   - on_update?: function(winid, bufnr) - Output callback (new console only)
---   - on_exit?: function(winid, bufnr) - Exit callback (new console only)
--- @return ConsoleInfo?
---
--- @usage
---   local console = require("aibo.internal.console_window")
---   -- Ensure single claude instance
---   console.focus_or_open("claude", nil, { opener = "split" })
function M.focus_or_open(cmd, args, options)
  options = options or {}

  local existing = M.find_info_in_tabpage({ cmd = cmd, args = args })
  if existing then
    if existing.winid == -1 then
      vim.cmd(string.format("%s %s", options.opener or "edit", vim.fn.fnameescape(existing.bufname)))
      local winid = vim.api.nvim_get_current_win()
      return {
        winid = winid,
        bufnr = existing.bufnr,
        bufname = existing.bufname,
        jobinfo = existing.jobinfo and {
          cmd = existing.jobinfo.cmd,
          args = existing.jobinfo.args,
          job_id = existing.jobinfo.job_id,
        } or nil,
      }
    else
      vim.api.nvim_set_current_win(existing.winid)
      return existing
    end
  end
  return M.open(cmd, args, options)
end

--- Toggle console visibility or create a new one if none exists.
--- - If visible: closes the window (buffer remains)
--- - If hidden: displays in a new window
--- - If not exists: creates a new console
---
--- @param cmd string The command to execute (e.g., "claude", "codex")
--- @param args? string[] Optional command arguments
--- @param options? table Optional configuration (same as M.open):
---   - opener?: string - Window command for showing hidden console
---   - on_update?: function(winid, bufnr) - Output callback (new console only)
---   - on_exit?: function(winid, bufnr) - Exit callback (new console only)
--- @return ConsoleInfo?
---
--- @usage
---   local console = require("aibo.internal.console_window")
---   -- Toggle claude console with keybinding
---   vim.keymap.set("n", "<leader>ai", function()
---     console.toggle_or_open("claude")
---   end)
function M.toggle_or_open(cmd, args, options)
  options = options or {}

  local existing = M.find_info_in_tabpage({ cmd = cmd, args = args })
  if existing then
    if existing.winid == -1 then
      vim.cmd(string.format("%s %s", options.opener or "edit", vim.fn.fnameescape(existing.bufname)))
      local winid = vim.api.nvim_get_current_win()
      return {
        winid = winid,
        bufnr = existing.bufnr,
        bufname = existing.bufname,
        jobinfo = existing.jobinfo and {
          cmd = existing.jobinfo.cmd,
          args = existing.jobinfo.args,
          job_id = existing.jobinfo.job_id,
        } or nil,
      }
    else
      vim.api.nvim_win_close(existing.winid, false)
      return {
        winid = -1, -- -1 indicates "no window"
        bufnr = existing.bufnr,
        bufname = existing.bufname,
        jobinfo = existing.jobinfo and {
          cmd = existing.jobinfo.cmd,
          args = existing.jobinfo.args,
          job_id = existing.jobinfo.job_id,
        } or nil,
      }
    end
  end
  return M.open(cmd, args, options)
end

--- Enable auto-scrolling for a console window.
--- Moves the cursor to the last line of the console buffer, which triggers
--- Neovim's automatic scrolling behavior to keep new output visible.
--- This is useful for monitoring active AI agent sessions where you want
--- to see the latest output as it arrives.
---
--- @param bufnr number The console buffer number to follow
--- @return nil No return value, sets cursor position directly
---
--- @usage
---   local console = require("aibo.internal.console_window")
---   -- Start following console output
---   console.follow(console_bufnr)
---
---   -- Typically used in autocmds or after receiving new output
---   vim.api.nvim_create_autocmd("TextChangedT", {
---     buffer = console_bufnr,
---     callback = function()
---       console.follow(console_bufnr)
---     end
---   })
function M.follow(bufnr)
  local info = M.get_info_by_bufnr(bufnr)
  if not info then
    vim.notify("Invalid buffer: " .. tostring(bufnr), vim.log.levels.ERROR, { title = "Aibo console Error" })
    return
  end
  -- Only move cursor if window is valid
  if info.winid ~= -1 and vim.api.nvim_win_is_valid(info.winid) then
    vim.api.nvim_win_set_cursor(info.winid, { vim.api.nvim_buf_line_count(bufnr), 0 })
  end
end

--- Send raw input to a console's terminal job.
--- Sends text directly to the terminal process without any additional processing.
--- Use this for sending control sequences or raw terminal input.
---
--- @param bufnr number The console buffer number
--- @param input string The text to send (can include escape sequences)
--- @return boolean|nil Returns true on success, nil on failure with error notification
---
--- @usage
---   local console = require("aibo.internal.console_window")
---   -- Send text to console
---   console.send(bufnr, "Hello, world")
---
---   -- Send control sequence
---   local termcode = require("aibo").termcode
---   console.send(bufnr, termcode.resolve("<C-c>"))  -- Send Ctrl-C
function M.send(bufnr, input)
  -- Do nothing for empty input
  if not input or input == "" then
    return true
  end
  if not M.get_info_by_bufnr(bufnr) then
    vim.notify("Invalid buffer: " .. tostring(bufnr), vim.log.levels.ERROR, { title = "Aibo console Error" })
    return
  end
  -- Get job ID from buffer (stored by M.open)
  local job_id = vim.b[bufnr].terminal_job_id
  if not job_id or job_id <= 0 then
    vim.notify(
      "No valid terminal job associated with buffer: " .. tostring(bufnr),
      vim.log.levels.ERROR,
      { title = "Aibo console Error" }
    )
    return nil
  end
  -- chansend returns the number of bytes sent, or 0 on failure
  if vim.fn.chansend(job_id, input) == 0 then
    vim.notify(
      string.format("Failed to send input to terminal job %d (Keycode: %s)", job_id, vim.fn.char2nr(input)),
      vim.log.levels.ERROR,
      { title = "Aibo console Error" }
    )
    return
  end
  return true
end

--- Submit input to console with automatic Enter key.
--- Sends the input text followed by a configurable submit key (default: Enter)
--- after a brief delay to ensure the agent receives the input properly.
---
--- @param bufnr number The console buffer number
--- @param input string The text to submit (command or message)
--- @return boolean|nil Returns true on success, nil on failure
---
--- @usage
---   local console = require("aibo.internal.console_window")
---   -- Submit a command to aider
---   console.submit(bufnr, "/add main.py")
---
---   -- Submit multiline input
---   console.submit(bufnr, "Fix the bug in\nthe authentication module")
---
--- @see aibo.get_config() for submit_key and submit_delay configuration
function M.submit(bufnr, input)
  local aibo = require("aibo")
  local termcode = require("aibo.internal.termcode")

  local config = aibo.get_config()
  local submit_key = termcode.resolve(config.submit_key) or "\r"
  local submit_delay = config.submit_delay

  -- First send input text
  if not M.send(bufnr, input) then
    -- Error already notified in M.send
    return nil
  end

  -- Send submit key after a short delay
  vim.defer_fn(function()
    M.send(bufnr, submit_key)
  end, submit_delay)

  return true
end

-- Initialize on module load
local augroup = vim.api.nvim_create_augroup("aibo_console_internal", { clear = true })
vim.api.nvim_create_autocmd("TermEnter", {
  group = augroup,
  pattern = string.format("%s://*", PREFIX),
  nested = true,
  callback = TermEnter,
})
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = augroup,
  pattern = string.format("%s://*", PREFIX),
  nested = true,
  callback = BufWinEnter,
})

return M
