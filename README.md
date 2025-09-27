# 🦾 nvim-aibo

[![Neovim](https://img.shields.io/badge/Neovim-0.10.0+-blueviolet.svg?style=flat-square&logo=Neovim&logoColor=white)](https://neovim.io/)
[![Lua](https://img.shields.io/badge/Lua-5.1+-blue.svg?style=flat-square&logo=lua)](https://www.lua.org/)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg?style=flat-square)](LICENSE)
[![Lua CI](https://github.com/lambdalisue/vim-aibo/actions/workflows/lua.yml/badge.svg)](https://github.com/lambdalisue/vim-aibo/actions/workflows/lua.yml)
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
> **Key mapping difference:** To prevent unintended interrupts from the Vimmer's habit of hitting `<Esc>` repeatedly, `<Esc>` is NOT mapped in Aibo buffers. Instead:
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

" Reuse existing console or open new one
:Aibo -reuse claude
```

> [!TIP]
> You can use `<C-r>=` to dynamically calculate window sizes based on your terminal dimensions. This allows you to create proportional splits instead of fixed sizes:
> ```vim
> " Create a vertical split with 2/3 of the window width
> :Aibo -opener="<C-r>=&columns * 2 / 3<CR>vsplit" claude
>
> " Create a horizontal split with 1/2 of the window height
> :Aibo -opener="<C-r>=&lines / 2<CR>split" codex
>
> " Create a bottom split with 1/3 of the window height
> :Aibo -opener="botright <C-r>=&lines / 3<CR>split" ollama run llama3
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
  prompt_height = 10,         -- Prompt window height (default: 10)
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

-- Override specific default mappings
vim.keymap.del('n', '<C-n>', { buffer = bufnr })
vim.keymap.del('n', '<C-p>', { buffer = bufnr })

-- Add your custom mappings
vim.keymap.set('n', '<Down>', '<Plug>(aibo-prompt-next)', { buffer = bufnr })
vim.keymap.set('n', '<Up>', '<Plug>(aibo-prompt-prev)', { buffer = bufnr })
```

```lua
-- ~/.config/nvim/after/ftplugin/aibo-tool-claude.lua
local bufnr = vim.api.nvim_get_current_buf()

-- Add leader-based mappings for Claude
vim.keymap.set('n', '<leader>cm', '<Plug>(aibo-claude-mode)', { buffer = bufnr })
vim.keymap.set('n', '<leader>cv', '<Plug>(aibo-claude-verbose)', { buffer = bufnr })
vim.keymap.set('n', '<leader>ct', '<Plug>(aibo-claude-todo)', { buffer = bufnr })
```

#### 2. Using on_attach callback

Configure mappings through the setup function:

```lua
require('aibo').setup({
  prompt = {
    on_attach = function(bufnr)
      -- Remove default mappings you don't want
      vim.keymap.del('n', '<C-n>', { buffer = bufnr })
      vim.keymap.del('n', '<C-p>', { buffer = bufnr })

      -- Add your own
      vim.keymap.set('n', '<Down>', '<Plug>(aibo-prompt-next)', { buffer = bufnr })
      vim.keymap.set('n', '<Up>', '<Plug>(aibo-prompt-prev)', { buffer = bufnr })
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
      -- Set your own mappings using <Plug> mappings
      vim.keymap.set('n', '<Enter>', '<Plug>(aibo-prompt-submit)', { buffer = bufnr })
      vim.keymap.set('n', '<C-q>', '<Plug>(aibo-prompt-submit-close)', { buffer = bufnr })
    end,
  },
})
```

## Key Mappings

### Console Buffer

| Key       | Action                          |
| --------- | ------------------------------- |
| `<CR>`    | Submit empty line               |
| `<C-c>`   | Send ESC to terminal            |
| `g<C-c>`  | Send interrupt signal           |
| `<C-l>`   | Clear terminal                  |
| `<C-n>`   | Navigate to next in history     |
| `<C-p>`   | Navigate to previous in history |
| `<Down>`  | Send down arrow                 |
| `<Up>`    | Send up arrow                   |

### Prompt Buffer

| Key           | Action                       |
| ------------- | ---------------------------- |
| `<CR>`        | Submit content (normal mode) |
| `<C-Enter>`\* | Submit and close             |
| `<F5>`        | Submit and close             |
| `:w`          | Submit content               |
| `:wq`         | Submit and close             |

Plus all console buffer mappings.

### Tool-Specific (Claude)

| Key                       | Action                   |
| ------------------------- | ------------------------ |
| `<S-Tab>`\* / `<F2>`      | Switch mode              |
| `<C-o>`                   | Toggle verbose           |
| `<C-t>`                   | Show todo                |
| `<C-_>` / `<C-->`         | Undo                     |
| `<C-v>`                   | Paste                    |
| `?`                       | Show shortcuts (n)       |
| `!`                       | Enter bash mode (n)      |
| `#`                       | Memorize context (n)     |

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
vim.keymap.set('n', '<C-j>', '<Plug>(aibo-prompt-submit)', { buffer = bufnr })
vim.keymap.set('n', '<C-k>', '<Plug>(aibo-prompt-submit-close)', { buffer = bufnr })
```

### Available <Plug> Mappings

#### Prompt Buffer

| <Plug> Mapping                     | Description       |
| ---------------------------------- | ----------------- |
| `<Plug>(aibo-prompt-submit)`       | Submit prompt     |
| `<Plug>(aibo-prompt-submit-close)` | Submit and close  |
| `<Plug>(aibo-prompt-esc)`          | Send ESC to tool  |
| `<Plug>(aibo-prompt-interrupt)`    | Interrupt tool    |
| `<Plug>(aibo-prompt-clear)`        | Clear screen      |
| `<Plug>(aibo-prompt-next)`         | Next history      |
| `<Plug>(aibo-prompt-prev)`         | Previous history  |
| `<Plug>(aibo-prompt-down)`         | Move down         |
| `<Plug>(aibo-prompt-up)`           | Move up           |

#### Console Buffer

| <Plug> Mapping                   | Description          |
| -------------------------------- | -------------------- |
| `<Plug>(aibo-console-submit)`    | Submit empty message |
| `<Plug>(aibo-console-close)`     | Close console        |
| `<Plug>(aibo-console-esc)`       | Send ESC to tool     |
| `<Plug>(aibo-console-interrupt)` | Interrupt tool       |
| `<Plug>(aibo-console-clear)`     | Clear screen         |
| `<Plug>(aibo-console-next)`      | Next history         |
| `<Plug>(aibo-console-prev)`      | Previous history     |
| `<Plug>(aibo-console-down)`      | Move down            |
| `<Plug>(aibo-console-up)`        | Move up              |

#### Claude Tool

| <Plug> Mapping                   | Description       |
| -------------------------------- | ----------------- |
| `<Plug>(aibo-claude-mode)`       | Toggle mode       |
| `<Plug>(aibo-claude-verbose)`    | Toggle verbose    |
| `<Plug>(aibo-claude-todo)`       | Show todo         |
| `<Plug>(aibo-claude-undo)`       | Undo              |
| `<Plug>(aibo-claude-paste)`      | Paste             |
| `<Plug>(aibo-claude-shortcuts)`  | Show shortcuts    |
| `<Plug>(aibo-claude-bash-mode)`  | Enter bash mode   |
| `<Plug>(aibo-claude-memorize)`   | Memorize context  |

#### Codex Tool

| <Plug> Mapping                  | Description     |
| ------------------------------- | --------------- |
| `<Plug>(aibo-codex-transcript)` | Show transcript |
| `<Plug>(aibo-codex-home)`       | Home            |
| `<Plug>(aibo-codex-end)`        | End             |
| `<Plug>(aibo-codex-page-up)`    | Page up         |
| `<Plug>(aibo-codex-page-down)`  | Page down       |
| `<Plug>(aibo-codex-quit)`       | Quit            |

### Tool-Specific Setup

Configure tool-specific behavior through setup:

```lua
require('aibo').setup({
  tools = {
    claude = {
      no_default_mappings = true,  -- Disable Claude-specific defaults
      on_attach = function(bufnr, info)
        -- Set your own Claude-specific mappings
        vim.keymap.set('n', '<leader>m', '<Plug>(aibo-claude-mode)', { buffer = bufnr })
        vim.keymap.set('n', '<leader>v', '<Plug>(aibo-claude-verbose)', { buffer = bufnr })
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
        vim.keymap.set('n', '<C-g>', function()
          require('aibo').send('\007', bufnr)
        end, { buffer = bufnr })
      end,
    },
  },
})
```

### Sending Keys to Terminal

When creating custom mappings that send keys to the terminal, **you must use `termcode.resolve()` instead of `vim.api.nvim_replace_termcodes()`**.

The built-in `nvim_replace_termcodes()` returns Neovim's internal key representations (e.g., `\x80\x6B\x75` for `<Up>`), which terminal programs cannot understand. The `termcode.resolve()` function converts Vim key notation to actual ANSI escape sequences (e.g., `\27[A` for `<Up>`) that terminals expect.

#### Correct Usage

```lua
local aibo = require('aibo')

-- Send navigation keys
vim.keymap.set('n', '<leader>au', function()
  aibo.send(aibo.termcode.resolve('<Up>'), bufnr)
end, { buffer = bufnr, desc = 'Send Up arrow' })

-- Send control sequences
vim.keymap.set('n', '<leader>ac', function()
  aibo.send(aibo.termcode.resolve('<C-c>'), bufnr)
end, { buffer = bufnr, desc = 'Interrupt process' })

-- Send multiple keys
vim.keymap.set('n', '<leader>ah', function()
  local keys = aibo.termcode.resolve('<Home><S-End>')
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
