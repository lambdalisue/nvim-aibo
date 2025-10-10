# 🐶 Aibo

[![Neovim](https://img.shields.io/badge/Neovim-0.10.0+-blueviolet.svg?style=flat-square&logo=Neovim&logoColor=white)](https://neovim.io/)
[![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg?style=flat-square&logo=lua)](https://www.lua.org/)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg?style=flat-square)](LICENSE)
[![Check](https://github.com/lambdalisue/vim-aibo/actions/workflows/check.yml/badge.svg)](https://github.com/lambdalisue/vim-aibo/actions/workflows/check.yml)
[![Test](https://github.com/lambdalisue/vim-aibo/actions/workflows/test.yml/badge.svg)](https://github.com/lambdalisue/vim-aibo/actions/workflows/test.yml)

AI Bot Integration and Orchestration for Neovim

> [!WARNING]
> This plugin is currently in **beta stage**. The API and features may change.

https://github.com/user-attachments/assets/ff48fe43-bc89-445c-8402-886df4d8e97d

<div align="right">
<sup>You can find more screencasts in <a href="https://github.com/lambdalisue/nvim-aibo/wiki/Screencast" target="_blank">Screencast</a> page of the repository Wiki</sup>
</div>

## Concept

Aibo (from Japanese "companion") is designed as your AI companion in Neovim, providing seamless integration with AI assistants while also supporting any interactive CLI tool.

- Pure Lua implementation for Neovim 0.10.0+
- **Optimized for AI assistants** with built-in support:
  - Claude (with mode switching, verbose toggle, todo management)
  - Codex (with transcript view, navigation controls)
  - Ollama (with model completion, thinking mode)
  - Works with Gemini and other AI CLI tools
- **Also works with any interactive CLI tool**:
  - Programming REPLs (python, node, irb, ghci)
  - Database clients (psql, mysql, sqlite3)
  - Custom interactive tools
- Split-window interface with console and prompt buffers
- Tool-specific configurations and key mappings
- Intelligent command completion for supported AI tools

## Requirements

- Neovim 0.10.0 or later
- An AI assistant CLI tool (claude, codex, ollama, etc.) or any other interactive CLI tool

## Installation

Use your preferred plugin manager.

### lazy.nvim

```lua
{
  'lambdalisue/nvim-aibo',
  -- Optional: setup can be omitted for default configuration
  config = function()
    require('aibo').setup()
  end,
}
```

### packer.nvim

```lua
use {
  'lambdalisue/nvim-aibo',
  -- Optional: setup can be omitted for default configuration
  config = function()
    require('aibo').setup()
  end,
}
```

## Health Check

Run `:checkhealth aibo` to verify your installation and diagnose any issues.

## Usage

### Basic Command Syntax

```vim
:Aibo [options] <command> [arguments...]
```

Where:

- `[options]` - Aibo-specific options (e.g., `-opener`, `-stay`, `-toggle`)
- `<command>` - Any interactive CLI tool command
- `[arguments...]` - Arguments passed directly to the CLI tool

This opens a terminal console running the interactive CLI tool with a prompt buffer below.

### Examples

```vim
" AI assistants with specialized support and smart completions
:Aibo claude
:Aibo claude --continue
:Aibo claude --model sonnet
:Aibo claude --permission-mode plan
:Aibo codex
:Aibo codex --model claude-3.5-sonnet
:Aibo codex resume --last
:Aibo ollama run llama3
:Aibo ollama run qwen3:latest --verbose
:Aibo gemini

" Also works with any interactive CLI tool
:Aibo python -i                 " Python REPL
:Aibo node --interactive        " Node.js REPL
:Aibo psql mydatabase          " PostgreSQL client
:Aibo sqlite3 data.db          " SQLite client
:Aibo my-custom-cli-tool       " Your custom tool
```

> [!NOTE]
> All Aibo commands support quoted strings for options with spaces.
>
> - Double quotes (`"`) interpret escape sequences: `-prefix="Line 1\nLine 2"`
> - Single quotes (`'`) treat everything literally: `-prefix='Literal\n'`
> - Example: `-opener="botright split"` or `-prefix='Question: '`

> [!WARNING]
>
> **Key mapping difference:** To prevent unintended interrupts from the Vimmer's habit of hitting `<Esc>` repeatedly, `<Esc>` is NOT mapped in Aibo buffers. Instead:
>
> - Use `<C-c>` to send `<Esc>` to the AI tool (works in both normal and insert mode)
> - Use `g<C-c>` to send the interrupt signal (original `<C-c>` behavior, normal mode only)

Type in the prompt buffer and press `<CR>` in normal mode to submit. The prompt clears automatically for the next message. You can also use `<C-Enter>` or `<F5>` to submit even while in insert mode, which is particularly useful for continuous typing.

> [!TIP]
> When focused on the console window, entering insert mode automatically opens the prompt window for input. This provides a seamless workflow - just press `i` in the console to start typing your next message.

To close the session, use `:bdelete!` or `:bwipeout!` on the console buffer.

### Window Control Options

```vim
" Open with custom window command
:Aibo -opener=vsplit claude
:Aibo -opener="botright split" claude

" Stay in current window after opening
:Aibo -stay claude

" Toggle visibility of existing console
:Aibo -toggle claude

" Focus on existing console or open new one
:Aibo -focus claude
```

> [!TIP]
> While Aibo provides predefined `-opener` completions, you can use any valid Vim window command. To dynamically size windows based on your terminal dimensions, use Neovim's [`<C-r>=`](https://neovim.io/doc/user/cmdline.html#c_CTRL-R_%3D) expression register:
>
> ```vim
> :Aibo -opener="<C-r>=&columns * 2 / 3<CR>vsplit" claude
> ```
>
> For better usability, we recommend defining custom commands or mappings:
>
> ```lua
> -- Custom command for Claude with proportional window
> vim.api.nvim_create_user_command('Claude', function(opts)
>   local width = math.floor(vim.o.columns * 2 / 3)
>   vim.cmd(string.format('Aibo -opener="%dvsplit" claude %s', width, opts.args))
> end, { nargs = '*' })
> ```
>
> ```lua
> -- Key mapping for quick access with dynamic sizing
> vim.keymap.set('n', '<leader>ai', function()
>   local width = math.floor(vim.o.columns * 2 / 3)
>   vim.cmd(string.format('Aibo -opener="%dvsplit" claude', width))
> end, { desc = 'Open Claude AI assistant' })
> ```

### Intelligent Command Completion

The plugin provides comprehensive tab completion for all supported interactive CLI tools:

- **Tool names**: Press `<Tab>` after `:Aibo ` to see available tools (claude, codex, ollama, or any custom tool)
- **Subcommands**: For ollama, complete `run` subcommand
- **Arguments**: Complete available flags and options for each tool
- **Values**: Complete predefined values for arguments (models, modes, etc.)
- **Models**: For ollama, automatically completes locally installed model names
- **Files/Directories**: Intelligent completion for file and directory arguments

Examples:

```vim
:Aibo <Tab>                     " Shows: claude, codex, ollama
:Aibo claude --<Tab>            " Shows all Claude arguments
:Aibo claude --model <Tab>      " Shows: sonnet, opus, haiku, etc.
:Aibo ollama <Tab>              " Shows: run
:Aibo ollama run <Tab>          " Shows installed models and flags
:Aibo ollama run qwen<Tab>      " Completes to: qwen3:latest
:Aibo codex --sandbox <Tab>     " Shows: none, read-only, restricted, full
```

### Sending Content to Interactive CLI

You can send buffer content directly to an interactive CLI console using the `:AiboSend` command:

````vim
" Send whole buffer to prompt
:AiboSend

" Send selected lines (visual mode)
:'<,'>AiboSend

" Send with options
:AiboSend -input    " Open prompt and enter insert mode
:AiboSend -submit   " Send and submit immediately
:AiboSend -replace  " Replace prompt content instead of appending

" Combine input and submit options
:AiboSend -input -submit  " Submit and immediately reopen for more input

" Send specific line range
:10,20AiboSend

" Add prefix and suffix to content
:AiboSend -prefix="Question: " -suffix=" Please explain."
:'<,'>AiboSend -prefix="```python\n" -suffix="\n```"

" Combine multiple options
:AiboSend -prefix="Review this code:\n" -submit
````

This is particularly useful for sending code snippets, error messages, or other content to the interactive CLI without manual copy-paste. The prefix and suffix options help format your input consistently.

## Configuration

### Basic Setup

```lua
require('aibo').setup({
  submit_delay = 100,         -- Delay in milliseconds (default: 100)
  submit_key = '<CR>',        -- Key to send after submit (default: '<CR>')
  prompt_height = 10,         -- Prompt window height (default: 10)
  termcode_mode = 'hybrid',   -- Terminal escape sequence mode: 'hybrid', 'xterm', or 'csi-n' (default: 'hybrid')
  disable_startinsert_on_startup = false, -- Disable auto insert in prompt window when first opened (default: false)
  disable_startinsert_on_insert = false,  -- Disable auto insert in prompt when entering insert from console (default: false)
})
```

### Advanced Configuration

The plugin works without any configuration, but you can customize it using `setup()`.
The setup function can be called multiple times to update configuration:

```lua
require('aibo').setup({
  -- Prompt buffer configuration
  prompt = {
    no_default_mappings = false,  -- Set to true to disable default keymaps
    on_attach = function(bufnr, info)
      -- Custom setup for prompt buffers
      -- Runs AFTER ftplugin files
      -- info.type = "prompt"
      -- info.tool = tool name (e.g., "claude")
      -- info.aibo = aibo instance
    end,
  },

  -- Console buffer configuration
  console = {
    no_default_mappings = false,
    on_attach = function(bufnr, info)
      -- Custom setup for console buffers
      -- info.type = "console"
      -- info.cmd = command being executed
      -- info.args = command arguments
      -- info.job_id = terminal job ID
    end,
  },

  -- Tool-specific overrides
  tools = {
    claude = {
      no_default_mappings = false,
      on_attach = function(bufnr, info)
        -- Custom setup for Claude buffers
        -- Called after prompt/console on_attach
      end,
    },
    codex = {
      -- Codex-specific configuration
    },
  },
})
```

#### Callback Order

When both buffer type and tool-specific `on_attach` callbacks are defined, both are called in this order:

1. Buffer type `on_attach` (e.g., `prompt.on_attach`)
2. Tool-specific `on_attach` (e.g., `tools.claude.on_attach`)

### Customizing Keymaps

Default keymaps are defined in ftplugin files. You can customize them in several ways:

#### 1. Using ftplugin files

Create your own ftplugin files in `~/.config/nvim/after/ftplugin/` to customize mappings:

```lua
-- ~/.config/nvim/after/ftplugin/aibo-prompt.lua
local bufnr = vim.api.nvim_get_current_buf()
local opts = { buffer = bufnr, nowait = true, silent = true }

-- Add your custom mappings using <Plug>(aibo-send) pattern
vim.keymap.set({ 'n', 'i' }, '<C-j>', '<Plug>(aibo-send)<Down>', opts)
vim.keymap.set({ 'n', 'i' }, '<C-k>', '<Plug>(aibo-send)<Up>', opts)
```

```lua
-- ~/.config/nvim/after/ftplugin/aibo-tool-claude.lua
local bufnr = vim.api.nvim_get_current_buf()
local opts = { buffer = bufnr, nowait = true, silent = true }

-- Add leader-based mappings using <Plug>(aibo-send) pattern
vim.keymap.set({ 'n', 'i' }, '<leader>a', '<Plug>(aibo-send)<Tab>', opts)
vim.keymap.set({ 'n', 'i' }, '<leader>m', '<Plug>(aibo-send)<S-Tab>', opts)
vim.keymap.set({ 'n', 'i' }, '<leader>t', '<Plug>(aibo-send)<C-t>', opts)
```

#### 2. Using on_attach callback

Configure mappings through the setup function:

```lua
require('aibo').setup({
  prompt = {
    on_attach = function(bufnr)
      local opts = { buffer = bufnr, nowait = true, silent = true }
      -- Add your own using <Plug>(aibo-send) pattern
      vim.keymap.set({ 'n', 'i' }, '<C-j>', '<Plug>(aibo-send)<Down>', opts)
      vim.keymap.set({ 'n', 'i' }, '<C-k>', '<Plug>(aibo-send)<Up>', opts)
    end,
  },
})
```

#### 3. Disable defaults and set your own

```lua
require('aibo').setup({
  prompt = {
    no_default_mappings = true,
    on_attach = function(bufnr)
      local opts = { buffer = bufnr, nowait = true, silent = true }
      -- Set your own mappings using <Plug> mappings
      vim.keymap.set('n', '<Enter>', '<Plug>(aibo-submit)', opts)
      vim.keymap.set('n', '<C-q>', '<Plug>(aibo-submit)<Cmd>q<CR>', opts)
      vim.keymap.set({ 'n', 'i' }, '<C-c>', '<Plug>(aibo-send)<Esc>', opts)
    end,
  },
})
```

## Key Mappings

> [!NOTE]
>
> `<C-g><C-o>` enters a special mode where you can press any single key to send it to the terminal. Useful for sending arbitrary keys not mapped by default.

### Console Buffer

Most keys use the `<Plug>(aibo-send)<Key>` pattern to send keys directly to the terminal:

| Key          | Action                          | Implementation            |
| ------------ | ------------------------------- | ------------------------- |
| `<CR>`       | Submit empty line               | `<Plug>(aibo-submit)`     |
| `<C-c>`      | Send ESC to terminal            | `<Plug>(aibo-send)<Esc>`  |
| `g<C-c>`     | Send interrupt signal           | `<Plug>(aibo-send)<C-c>`  |
| `<C-l>`      | Clear terminal                  | `<Plug>(aibo-send)<C-l>`  |
| `<C-n>`      | Navigate to next in history     | `<Plug>(aibo-send)<C-n>`  |
| `<C-p>`      | Navigate to previous in history | `<Plug>(aibo-send)<C-p>`  |
| `<Down>`     | Send down arrow                 | `<Plug>(aibo-send)<Down>` |
| `<Up>`       | Send up arrow                   | `<Plug>(aibo-send)<Up>`   |
| `<C-g><C-o>` | Send any single key (n)         | `<Plug>(aibo-send)`       |

### Prompt Buffer

| Key           | Action                    | Implementation                  |
| ------------- | ------------------------- | ------------------------------- |
| `<CR>`        | Submit content (n)        | `<Plug>(aibo-submit)`           |
| `<C-Enter>`\* | Submit and close (n/i)    | `<Plug>(aibo-submit)<Cmd>q<CR>` |
| `<F5>`        | Submit and close (n/i)    | `<Plug>(aibo-submit)<Cmd>q<CR>` |
| `<C-g><C-o>`  | Send any single key (n/i) | `<Plug>(aibo-send)`             |

Plus all console buffer mappings (with `<Plug>(aibo-send)<Key>` pattern).

### Tool-Specific (Claude)

All Claude-specific keys use the `<Plug>(aibo-send)` pattern to send keys directly to the Claude CLI:

| Key                  | Action         |
| -------------------- | -------------- |
| `<Tab>`              | Toggle think   |
| `<S-Tab>`\* / `<F2>` | Switch mode    |
| `<C-o>`              | Toggle verbose |
| `<C-t>`              | Show todo      |
| `<C-_>` / `<C-->`    | Undo           |
| `<C-v>`              | Paste          |

### Tool-Specific (Codex)

| Key          | Action          |
| ------------ | --------------- |
| `<C-t>`      | Show transcript |
| `<Home>`     | Home            |
| `<End>`      | End             |
| `<PageUp>`   | Page up         |
| `<PageDown>` | Page down       |
| `q`          | Quit            |

> [!IMPORTANT]
> Some key combinations (`<C-Enter>`, `<S-Tab>`) require modern terminal emulators like Kitty, WezTerm, or Ghostty. Use alternatives like `<F5>` or `:w` if these don't work.

## Customization

### Using <Plug> Mappings

All functionality is exposed through `<Plug>` mappings defined in ftplugin files:

```lua
-- In your configuration or on_attach callback
local opts = { buffer = bufnr, nowait = true, silent = true }
vim.keymap.set('n', '<C-j>', '<Plug>(aibo-submit)', opts)
vim.keymap.set('n', '<C-k>', '<Plug>(aibo-submit)<Cmd>q<CR>', opts)
```

### Available <Plug> Mappings

#### Core Mappings (Console and Prompt Buffers)

| <Plug> Mapping        | Description                                     |
| --------------------- | ----------------------------------------------- |
| `<Plug>(aibo-send)`   | Prefix for sending keys to terminal (see below) |
| `<Plug>(aibo-submit)` | Submit content to terminal                      |

The `<Plug>(aibo-send)` mapping is designed to be used as a prefix followed by a key:

- `<Plug>(aibo-send)<Esc>` - Send ESC to terminal
- `<Plug>(aibo-send)<C-c>` - Send interrupt signal
- `<Plug>(aibo-send)<C-l>` - Send clear screen
- `<Plug>(aibo-send)<C-n>` - Send next history
- `<Plug>(aibo-send)<C-p>` - Send previous history
- `<Plug>(aibo-send)<Down>` - Send down arrow
- `<Plug>(aibo-send)<Up>` - Send up arrow
- `<Plug>(aibo-send)<Tab>` - Send tab (Claude: accept)
- `<Plug>(aibo-send)<S-Tab>` - Send shift-tab (Claude: mode switch)
- And any other key you want to send to the terminal

#### Claude Tool

Uses `<Plug>(aibo-send)<Key>` pattern (defined in `ftplugin/aibo-tool-claude.lua`):

```lua
vim.keymap.set({ "n", "i" }, "<Tab>", "<Plug>(aibo-send)<Tab>", opts)
vim.keymap.set({ "n", "i" }, "<S-Tab>", "<Plug>(aibo-send)<S-Tab>", opts)
vim.keymap.set({ "n", "i" }, "<F2>", "<Plug>(aibo-send)<F2>", opts)
vim.keymap.set({ "n", "i" }, "<C-o>", "<Plug>(aibo-send)<C-o>", opts)
vim.keymap.set({ "n", "i" }, "<C-t>", "<Plug>(aibo-send)<C-t>", opts)
vim.keymap.set({ "n", "i" }, "<C-_>", "<Plug>(aibo-send)<C-_>", opts)
vim.keymap.set({ "n", "i" }, "<C-v>", "<Plug>(aibo-send)<C-v>", opts)
```

#### Codex Tool

Uses `<Plug>(aibo-send)<Key>` pattern (defined in `ftplugin/aibo-tool-codex.lua`):

```lua
vim.keymap.set({ "n", "i" }, "<C-t>", "<Plug>(aibo-send)<C-t>", opts)
vim.keymap.set({ "n", "i" }, "<Home>", "<Plug>(aibo-send)<Home>", opts)
vim.keymap.set({ "n", "i" }, "<End>", "<Plug>(aibo-send)<End>", opts)
vim.keymap.set({ "n", "i" }, "<PageUp>", "<Plug>(aibo-send)<PageUp>", opts)
vim.keymap.set({ "n", "i" }, "<PageDown>", "<Plug>(aibo-send)<PageDown>", opts)
vim.keymap.set("n", "q", "<Plug>(aibo-send)q", opts)
```

### Tool-Specific Setup

Configure tool-specific behavior through setup:

```lua
require('aibo').setup({
  tools = {
    claude = {
      no_default_mappings = true,  -- Disable Claude-specific defaults
      on_attach = function(bufnr, info)
        local opts = { buffer = bufnr, nowait = true, silent = true }
        -- Set your own Claude-specific mappings using <Plug>(aibo-send) pattern
        vim.keymap.set({ 'n', 'i' }, '<leader>a', '<Plug>(aibo-send)<Tab>', opts)
        vim.keymap.set({ 'n', 'i' }, '<leader>m', '<Plug>(aibo-send)<S-Tab>', opts)
        vim.keymap.set({ 'n', 'i' }, '<leader>v', '<Plug>(aibo-send)<C-o>', opts)
      end,
    },
  },
})
```

### Adding New Tools

Define custom tools with their own configuration:

```lua
require('aibo').setup({
  tools = {
    myai = {
      no_default_mappings = false,
      on_attach = function(bufnr, info)
        local opts = { buffer = bufnr, nowait = true, silent = true }
        -- Use <Plug>(aibo-send) pattern to send keys to your AI tool
        vim.keymap.set({ 'n', 'i' }, '<C-g>', '<Plug>(aibo-send)<C-g>', opts)
        vim.keymap.set({ 'n', 'i' }, '<F6>', '<Plug>(aibo-send)<F6>', opts)
      end,
    },
  },
})
```

### Sending Keys to Terminal

**Recommended approach:** Use the `<Plug>(aibo-send)<Key>` pattern for most cases:

```lua
local opts = { buffer = bufnr, nowait = true, silent = true }
vim.keymap.set({ 'n', 'i' }, '<C-g>', '<Plug>(aibo-send)<C-g>', opts)
```

This automatically handles key conversion and sends the correct terminal sequences.

**Advanced usage:** For programmatic key sending, use `aibo.resolve()` instead of `vim.api.nvim_replace_termcodes()`.

The built-in `nvim_replace_termcodes()` returns Neovim's internal key representations (e.g., `\x80\x6B\x75` for `<Up>`), which terminal programs cannot understand. The `aibo.resolve()` function converts Vim key notation to actual ANSI escape sequences (e.g., `\27[A` for `<Up>`) that terminals expect.

#### Correct Usage

```lua
local aibo = require('aibo')

-- Send navigation keys
vim.keymap.set('n', '<leader>au', function()
  aibo.send(aibo.resolve('<Up>'), bufnr)
end, { buffer = bufnr, desc = 'Send Up arrow' })

-- Send control sequences
vim.keymap.set('n', '<leader>ac', function()
  aibo.send(aibo.resolve('<C-c>'), bufnr)
end, { buffer = bufnr, desc = 'Interrupt process' })

-- Send multiple keys
vim.keymap.set('n', '<leader>ah', function()
  local keys = aibo.resolve('<Home><S-End>')
  aibo.send(keys, bufnr)
end, { buffer = bufnr, desc = 'Select to end of line' })
```

#### Incorrect Usage (Will Not Work)

```lua
-- ❌ This sends Neovim's internal codes, not terminal sequences!
vim.keymap.set('n', '<leader>au', function()
  local up = vim.api.nvim_replace_termcodes('<Up>', true, false, true)
  aibo.send(up, bufnr)  -- Sends "\x80\x6B\x75" instead of "\27[A"
end, { buffer = bufnr })
```

#### Supported Key Formats

- **Navigation**: `<Up>`, `<Down>`, `<Left>`, `<Right>`, `<Home>`, `<End>`
- **Pages**: `<PageUp>`, `<PageDown>`
- **Function**: `<F1>` through `<F12>`
- **Control**: `<C-a>`, `<C-c>`, `<C-l>`, etc.
- **Modified**: `<S-Tab>`, `<C-Left>`, `<A-Up>`, `<C-S-F5>`, etc.
- **Special**: `<CR>`, `<Tab>`, `<Esc>`, `<Space>`, `<BS>`

#### Terminal Compatibility Modes

The `termcode_mode` configuration controls how modified control characters are encoded:

- **`hybrid`** (default): Uses traditional xterm sequences where widely supported (e.g., `\27[Z` for `<S-Tab>`), falls back to modern CSI sequences for others
- **`xterm`**: Strictly uses traditional xterm sequences, returns `nil` for unsupported combinations
- **`csi-n`**: Consistently uses modern CSI n;mu format (e.g., `\27[9;2u` for `<S-Tab>`)

Most users should use the default `hybrid` mode. Use `xterm` for older terminals or `csi-n` for modern terminals with full modifier support.

## License

MIT License

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:

- Development setup and workflow
- Architecture documentation
- Testing guidelines
- API documentation
- Code style guide

For quick reference:

1. Fork and clone the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

Report issues and submit pull requests on [GitHub](https://github.com/lambdalisue/nvim-aibo)
