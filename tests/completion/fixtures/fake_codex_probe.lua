-- Fake `codex app-server` responder for testing aibo.completion.codex's live
-- probe. Run via `nvim -l fake_codex_probe.lua`. Speaks newline-delimited
-- JSON-RPC on stdio:
--   {"id":1,"method":"initialize",...} -> {"id":1,"result":{...}}
--   {"id":2,"method":"skills/list",...} -> {"id":2,"result":{"data":[...]}}
-- It never expects (or answers) a `thread/start` request; this mirrors the
-- real `codex app-server` control channel that the module talks to directly
-- (see completion/codex.lua).

local function send(obj)
  io.write(vim.json.encode(obj) .. "\n")
  io.flush()
end

-- Recorded payload. Includes a skill with no description and a malformed
-- (non-table) entry to exercise the parser's defensive filtering.
local SKILLS = {
  { name = "help", description = "Show help and available commands" },
  { name = "clear", description = "Start a new conversation with empty context" },
  -- A skill that exists only in the live probe payload (not in any static
  -- base). Used by tests to prove the probed list supersedes disk-scanned
  -- skills.
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
        send({ id = msg.id, result = { codexHome = "/fake/.codex" } })
      elseif msg.method == "skills/list" then
        send({
          id = msg.id,
          result = {
            data = {
              { cwd = "/fake/cwd", skills = SKILLS, errors = {} },
            },
          },
        })
      end
    end
  end
end
