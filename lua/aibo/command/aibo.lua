local M = {}

local OPENERS = {
  "-opener=split",
  "-opener=vsplit",
  "-opener=tabedit",
  "-opener=edit",
  "-opener=topleft\\ split",
  "-opener=topleft\\ vsplit",
  "-opener=botright\\ split",
  "-opener=botright\\ vsplit",
  "-opener=leftabove\\ split",
  "-opener=leftabove\\ vsplit",
  "-opener=rightbelow\\ split",
  "-opener=rightbelow\\ vsplit",
}

--- Internal completion function for Aibo command
--- @param arglead string Current argument being completed
--- @param cmdline string Full command line
--- @param cursorpos number Cursor position
--- @return string[] List of completions
local function complete(arglead, cmdline, cursorpos)
  local argparse = require("aibo.internal.argparse")
  local integration = require("aibo.integration")
  local known_options = {
    opener = true, -- -opener=value
    stay = false, -- -stay flag
    toggle = false, -- -toggle flag
    reuse = false, -- -reuse flag
  }

  -- Parse command line to determine tool completion context first
  local state = argparse.parse_for_completion(cmdline, known_options)
  local known_tools = integration.available_integrations()

  -- Filter out empty strings from remaining
  local non_empty_remaining = vim.tbl_filter(function(arg)
    return arg ~= ""
  end, state.remaining)

  -- Determine completion mode based on remaining arguments
  if #non_empty_remaining == 0 then
    -- No arguments yet - handle global options or offer tool names
    if arglead:match("^-opener=") then
      return vim.tbl_filter(function(val)
        return val:find("^" .. vim.pesc(arglead))
      end, OPENERS)
    elseif arglead:match("^%-") then
      return argparse.get_option_completions(arglead, cmdline, known_options)
    else
      local options = argparse.get_option_completions(arglead, cmdline, known_options)
      local tools = vim.tbl_filter(function(val)
        return arglead == "" or val:find("^" .. vim.pesc(arglead))
      end, known_tools)
      -- Combine options and tools tables
      local combined = vim.list_extend(vim.deepcopy(options), tools)
      return combined
    end
  elseif #non_empty_remaining == 1 then
    -- Only one argument - check if it's a complete known tool or partial tool name
    local first_arg = non_empty_remaining[1]

    if vim.tbl_contains(known_tools, first_arg) then
      -- Complete known tool - switch to tool-specific completion mode
      -- (handled below)
      goto tool_specific
    else
      -- Incomplete or unknown argument - stay in tool name completion mode
      if arglead:match("^%-") then
        -- But if arglead is an option, handle global options
        return argparse.get_option_completions(arglead, cmdline, known_options)
      elseif arglead ~= "" then
        -- Complete tool names only if we have a partial arglead
        return vim.tbl_filter(function(val)
          return val:find("^" .. vim.pesc(arglead))
        end, known_tools)
      else
        -- Empty arglead with unknown tool - no completions
        return {}
      end
    end
  else
    -- Multiple arguments - check if first argument is a known tool
    local first_arg = non_empty_remaining[1]
    if not vim.tbl_contains(known_tools, first_arg) then
      -- First argument is not a known tool - fallback to no completions
      return {}
    end
    -- First argument is a known tool - proceed to tool-specific completion
  end

  ::tool_specific::
  -- Tool-specific completion mode
  local tool = non_empty_remaining[1]

  -- Build clean command line for tool integration
  -- We need to extract everything after the tool name from the original cmdline
  -- to preserve tool-specific options that come after the tool name
  local tool_start_pos = cmdline:find(vim.pesc(tool))
  if not tool_start_pos then
    return {}
  end

  local tool_cmdline = cmdline:sub(tool_start_pos)
  local tool_cursorpos = cursorpos - (tool_start_pos - 1)
  if tool_cursorpos < 0 then
    tool_cursorpos = 0
  end

  -- Delegate to tool integration
  return integration.get_command_completions(tool, arglead, tool_cmdline, tool_cursorpos)
end

--- Execute Aibo command with given arguments and options
--- @param args string[] Arguments array (e.g., {"claude", "--continue"})
--- @param options? table Options table { opener?: string, stay?: boolean, toggle?: boolean, reuse?: boolean }
--- @return nil
function M.call(args, options)
  if not args or type(args) ~= "table" or #args == 0 then
    vim.notify(
      "Usage: require('aibo.command.aibo').call(args, options) where args is a non-empty array",
      vim.log.levels.INFO,
      { title = "Aibo" }
    )
    return
  end

  options = options or {}

  -- Extract command and remaining args
  local cmd_args = vim.deepcopy(args)
  local cmd = table.remove(cmd_args, 1)

  -- Extract and validate options
  local opener = options.opener
  local stay = options.stay or false
  local toggle = options.toggle or false
  local reuse = options.reuse or false

  -- Validate mutually exclusive options
  if toggle and reuse then
    vim.notify("Error: -toggle and -reuse cannot be used together", vim.log.levels.WARN, { title = "Aibo" })
    return
  end

  local original_winid = vim.api.nvim_get_current_win()

  -- Use appropriate behavior based on options
  local console = require("aibo.internal.console_window")
  local console_options = {
    opener = opener,
  }
  if toggle then
    console.toggle_or_open(cmd, cmd_args, console_options)
  elseif reuse then
    console.focus_or_open(cmd, cmd_args, console_options)
  else
    console.open(cmd, cmd_args, console_options)
  end
  if stay then
    vim.api.nvim_set_current_win(original_winid)
  end
end

--- Create Aibo user command with all functionality
--- @return nil
function M.setup()
  vim.api.nvim_create_user_command("Aibo", function(cmd_opts)
    local args = cmd_opts.fargs
    if #args == 0 then
      vim.notify(
        "Usage: :Aibo [-opener=<opener>] [-stay] [-toggle|-reuse] <cmd> [args...]",
        vim.log.levels.INFO,
        { title = "Aibo" }
      )
      return
    end

    -- Parse options using the argparse module
    local argparse = require("aibo.internal.argparse")
    -- Define known Aibo command options
    local known_options = {
      opener = true, -- -opener=value
      stay = true, -- -stay
      toggle = true, -- -toggle
      reuse = true, -- -reuse
    }
    local options, remaining = argparse.parse(args, { known_options = known_options })

    -- Extract specific options
    local opener = options.opener
    local stay = options.stay or false
    local toggle = options.toggle or false
    local reuse = options.reuse or false

    if opener == "" then
      vim.notify(
        "Usage: :Aibo [-opener=<opener>] [-stay] [-toggle|-reuse] <cmd> [args...]\nExample: :Aibo -opener=vsplit -stay ollama run llama3.2",
        vim.log.levels.INFO,
        { title = "Aibo" }
      )
      return
    end

    if #remaining == 0 then
      vim.notify(
        "Usage: :Aibo [-opener=<opener>] [-stay] [-toggle|-reuse] <cmd> [args...]",
        vim.log.levels.INFO,
        { title = "Aibo" }
      )
      return
    end

    -- Call the API function with args array
    M.call(remaining, {
      opener = opener,
      stay = stay,
      toggle = toggle,
      reuse = reuse,
    })
  end, {
    nargs = "+",
    desc = "Open an interactive Aibo console",
    complete = complete,
  })
end

-- Internal API for testing - should not be used by end users
M._internal = {
  complete = complete,
}

return M
