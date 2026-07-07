-- Minimal fake ACP adapter for testing the generic aibo.completion.acp
-- client (used by agents that speak ACP natively, e.g. Gemini CLI).
-- Run via `nvim -l fake_acp.lua`. Speaks newline-delimited JSON-RPC on stdio:
--   initialize  -> result { protocolVersion, agentCapabilities, authMethods }
--   session/new -> result { sessionId }, then pushes an available_commands_update
--                  notification carrying a recorded payload.
-- It never expects a prompt; this mirrors a real ACP-native agent's
-- post-session push.

local function send(obj)
  io.write(vim.json.encode(obj) .. "\n")
  io.flush()
end

-- Recorded payload. Includes a command with no description and a malformed
-- (non-table) entry to exercise the parser's defensive filtering.
local AVAILABLE_COMMANDS = {
  { name = "help", description = "Show help and available commands" },
  { name = "clear", description = "Start a new conversation with empty context" },
  { name = "model", description = "Select or change the AI model" },
  -- A command that exists only in the ACP payload (not in a static builtin
  -- table). Used by tests to prove the ACP list supersedes any static base.
  { name = "acp-only-marker", description = "Only delivered via ACP" },
  { name = "no-desc" },
  "garbage-string",
}

for line in io.lines() do
  line = vim.trim(line)
  if line ~= "" then
    local ok, msg = pcall(vim.json.decode, line)
    if ok and type(msg) == "table" and msg.method then
      if msg.method == "initialize" then
        send({
          jsonrpc = "2.0",
          id = msg.id,
          result = {
            protocolVersion = 1,
            agentCapabilities = vim.empty_dict(),
            authMethods = {},
          },
        })
      elseif msg.method == "session/new" then
        send({ jsonrpc = "2.0", id = msg.id, result = { sessionId = "fake-session-1" } })
        send({
          jsonrpc = "2.0",
          method = "session/update",
          params = {
            sessionId = "fake-session-1",
            update = {
              sessionUpdate = "available_commands_update",
              availableCommands = AVAILABLE_COMMANDS,
            },
          },
        })
      end
    end
  end
end
