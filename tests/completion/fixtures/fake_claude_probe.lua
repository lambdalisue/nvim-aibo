-- Fake `claude` stream-json control-protocol responder for testing
-- aibo.completion.claude's live probe. Run via `nvim -l fake_claude_probe.lua`.
-- Speaks newline-delimited JSON on stdio:
--   control_request{subtype="initialize"} -> control_response{subtype="success",
--     response={commands=[...]}}
-- It never expects (or answers) a prompt turn; this mirrors the real
-- `claude --input-format stream-json --output-format stream-json` control
-- channel that the module talks to directly (see completion/claude.lua).

local function send(obj)
  io.write(vim.json.encode(obj) .. "\n")
  io.flush()
end

-- Recorded payload. Includes a command with no description and a malformed
-- (non-table) entry to exercise the parser's defensive filtering.
local COMMANDS = {
  { name = "help", description = "Show help and available commands" },
  { name = "clear", description = "Start a new conversation with empty context" },
  { name = "model", description = "Select or change the AI model" },
  -- A command that exists only in the live probe payload (not in the static
  -- builtin table). Used by tests to prove the probed list supersedes the
  -- builtin base.
  { name = "acp-only-marker", description = "Only delivered via ACP" },
  { name = "no-desc" },
  "garbage-string",
}

for line in io.lines() do
  line = vim.trim(line)
  if line ~= "" then
    local ok, msg = pcall(vim.json.decode, line)
    if ok and type(msg) == "table" and msg.type == "control_request" then
      local request = msg.request or {}
      if request.subtype == "initialize" then
        send({
          type = "control_response",
          response = {
            subtype = "success",
            request_id = msg.request_id,
            response = { commands = COMMANDS },
          },
        })
      end
    end
  end
end
