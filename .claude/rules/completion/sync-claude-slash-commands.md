---
paths: "lua/aibo/completion/claude.lua"
---

# Syncing the Claude Code built-in slash command list

`BUILTIN_COMMANDS` in `lua/aibo/completion/claude.lua` is the slash-command
completion list for the aibo prompt. When syncing or verifying it against the
latest Claude Code, follow this method.

## 1. Source of truth = the docs

Use `https://code.claude.com/docs/en/commands` (the file header's declared
reference). The file's descriptions track the docs wording, NOT the binary's —
do NOT rewrite descriptions toward the binary.

Watch for rows marked "Removed in vX.Y.Z" (e.g. `/pr-comments` removed in
v2.1.91, `/vim` in v2.1.92). Exclude these even though docs still list them.

## 2. Binary = diagnostic only

Use the installed binary to settle inclusion decisions and aliases, NOT
wording. It is a minified JS bundle at `~/.local/share/claude/versions/<version>`
(resolve via `readlink -f $(which claude)`). Command objects look like:

```text
{type:"local-jsx"|"prompt"|"local",name:"X",aliases:["..."],description:"..."}
```

Extract candidates with:

```sh
perl -ne 'while(/type:"(local|local-jsx|prompt)",name:"([^"]+)"(?:,aliases:\[([^\]]*)\])?,description:"((?:[^"\\]|\\.)*)"/g){print "$2\t[$3]\t$4\n"}' "$BIN" | sort -u
```

EXCLUDE commands gated by `isEnabled:()=>!1`, `isHidden:!0`, or feature flags
(`isEnabled:()=>ut("flag",!1)`) — they are not generally available, so they do
not belong in the completion list.

Caveat: key order varies and some descriptions are getters
(`get description(){...}`), so the regex above undercounts. Confirm individual
commands and aliases with targeted greps, e.g.
`grep -ao 'name:"rewind"[^}]\{0,200\}' "$BIN"`.

## 3. File conventions

- Keep entries in alphabetical order by `cmd`.
- Each alias is its own row with a `(alias for /X)` suffix; verify the alias
  still appears in the binary parent's `aliases:[...]`.
- Bundled skills/workflows get a `(skill)` suffix.

## 4. Checks

- `just lint` (luacheck) and `stylua --check lua/aibo/completion/claude.lua`
- `just test-file FILE=tests/completion/test_claude.lua`

Note: a geometry case in `tests/internal/test_prompt_window.lua` fails in
headless mode regardless of this file — it is pre-existing and unrelated.
