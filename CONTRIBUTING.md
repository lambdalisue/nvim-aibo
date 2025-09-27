# Contributing to nvim-aibo

Thank you for your interest in contributing to nvim-aibo! This guide provides everything you need to know about contributing to the project.

## Table of Contents

- [Development Setup](#development-setup)
- [Architecture](#architecture)
- [Code Style](#code-style)
- [Testing](#testing)
- [API Documentation](#api-documentation)
- [Making Changes](#making-changes)
- [Submitting Pull Requests](#submitting-pull-requests)
- [Development Workflow](#development-workflow)

## Development Setup

### Prerequisites

- Neovim 0.10.0 or later
- Lua 5.1 or LuaJIT
- Git
- [just](https://github.com/casey/just) (optional, for task automation)

### Initial Setup

1. Fork and clone the repository:
```bash
git clone https://github.com/your-username/nvim-aibo.git
cd nvim-aibo
```

2. Install development dependencies:
```bash
# Install mini.test for testing (if not already installed)
git clone https://github.com/echasnovski/mini.nvim.git /tmp/mini.nvim
cp -r /tmp/mini.nvim/lua/mini/test.lua ~/.local/share/nvim/site/pack/vendor/start/mini.nvim/lua/mini/
```

3. Run health check:
```vim
:checkhealth aibo
```

## Architecture

The plugin follows a modular architecture with clear separation of concerns:

```
lua/aibo/
├── command/                    # Command modules
│   ├── aibo.lua               # Main Aibo command implementation
│   └── aibo_send.lua          # AiboSend command implementation
├── integration/               # AI tool integrations
│   ├── claude.lua            # Claude-specific features and mappings
│   ├── codex.lua             # Codex-specific features and mappings
│   └── ollama.lua            # Ollama-specific features and mappings
├── internal/                  # Internal utilities
│   ├── argparse.lua          # Command argument parsing
│   ├── console_window.lua    # Console window management
│   ├── prompt_window.lua     # Prompt window management
│   ├── timing.lua            # Debounce and throttle utilities
│   └── argparse.lua          # Command argument parsing
├── health.lua                # Health check implementation
└── init.lua                  # Main module entry point

plugin/
└── aibo.lua                  # Vim command registration

ftplugin/
├── aibo-prompt.lua           # Prompt buffer filetype settings
├── aibo-console.lua          # Console buffer filetype settings
├── aibo-tool-claude.lua      # Claude-specific mappings
├── aibo-tool-codex.lua       # Codex-specific mappings
└── aibo-tool-ollama.lua      # Ollama-specific mappings
```

### Key Architectural Principles

1. **Separation of Concerns**
   - Command modules handle user-facing commands
   - Integration modules own their `<Plug>` mappings
   - Internal modules provide shared utilities
   - Clear boundaries between console, prompt, and controller

2. **Module Responsibilities**
   - `command/`: User command parsing and execution
   - `integration/`: Tool-specific features and behaviors
   - `internal/`: Core functionality and utilities
   - `ftplugin/`: Buffer-specific settings and mappings

3. **Data Flow**
   - Commands → Controller → Terminal Process
   - User Input → Prompt → Send → Console
   - Tool Output → Console → User Display

## Code Style

### Lua Style Guide

1. **Naming Conventions**
   - Use `snake_case` for variables and functions
   - Use `PascalCase` for classes/modules
   - Prefix private functions with underscore `_`
   - Use descriptive names

2. **Documentation**
   - Use LuaLS annotations for all public functions
   - Document complex logic with inline comments
   - Keep comments concise and relevant

3. **Code Structure**
   ```lua
   -- Module header
   local M = {}

   -- Dependencies
   local utils = require("aibo.internal.utils")

   --- Public function with documentation
   ---@param param string Parameter description
   ---@return string result Return value description
   function M.public_function(param)
     -- Implementation
   end

   -- Private helper function
   local function _private_helper()
     -- Implementation
   end

   return M
   ```

4. **Error Handling**
   - Use `assert()` for programmer errors
   - Use `vim.notify()` for user-facing errors
   - Always validate user input

### Linting

Run luacheck before submitting:
```bash
luacheck .
# or
just lint
```

Configuration is in `.luacheckrc`.

## Testing

The project uses [mini.test](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-test.md) for unit testing.

### Test Structure

```
tests/
├── unit/                       # Unit tests for core modules
│   ├── test_aibo_core.lua    # Core module tests
│   ├── test_argparse.lua     # Argument parsing tests
│   └── test_console.lua      # Console management tests
├── integrations/              # Integration tests
│   ├── test_claude.lua       # Claude integration tests
│   ├── test_codex.lua        # Codex integration tests
│   └── test_ollama.lua       # Ollama integration tests
├── commands/                  # Command tests
│   ├── test_aibo_command.lua # Aibo command tests
│   └── test_aibo_send_command.lua # AiboSend command tests
├── plugin/                    # Plugin-level tests
│   └── test_plugin_setup.lua # Plugin setup and initialization
├── helpers.lua               # Common test utilities
└── test_runner.lua          # Main test runner
```

### Running Tests

Using `just`:
```bash
just test           # Run all tests
just test-file aibo # Run specific test file
just test-watch     # Run tests in watch mode
just check          # Run lint, format, and tests
```

Direct execution:
```bash
nvim --headless -c "luafile tests/test_runner.lua" -c "qa!"
```

### Writing Tests

Tests are organized using mini.test's test sets:

```lua
local helpers = require("tests.helpers")
local T = require("mini.test")

local test_set = T.new_set()

-- Setup/teardown hooks
test_set.hooks.pre_case = function()
  helpers.setup()  -- Clean environment
end

test_set.hooks.post_case = function()
  helpers.cleanup()  -- Clean up
end

-- Test cases
test_set["function_name works correctly"] = function()
  -- Arrange
  local input = "test"

  -- Act
  local result = module.function_name(input)

  -- Assert
  T.expect.equality(result, "expected")
end

test_set["handles edge cases"] = function()
  -- Test edge cases and error conditions
  T.expect.error(function()
    module.function_name(nil)
  end)
end

return test_set
```

### Test Guidelines

1. **Test Organization**
   - One test file per module
   - Group related tests in the same file
   - Use descriptive test names

2. **Test Coverage**
   - Test public API thoroughly
   - Include edge cases and error conditions
   - Test integration points

3. **Test Quality**
   - Keep tests focused and independent
   - Use helpers to reduce duplication
   - Mock external dependencies when needed

## API Documentation

### Core API

```lua
local aibo = require('aibo')

-- Configure the plugin
aibo.setup({
  submit_delay = 150,
  prompt_height = 10,
  -- ... other configuration
})

-- Send raw data to terminal
---@param data string Data to send
---@param bufnr number Buffer number
aibo.send(data, bufnr)

-- Submit with automatic return key
---@param text string Text to submit
---@param bufnr number Buffer number
aibo.submit(text, bufnr)

-- Get current configuration
---@return table config
local config = aibo.get_config()

-- Get buffer type configuration
---@param type string "prompt" or "console"
---@return table config
local prompt_cfg = aibo.get_buffer_config(type)

-- Get tool-specific configuration
---@param tool string Tool name (e.g., "claude")
---@return table config
local tool_cfg = aibo.get_tool_config(tool)
```

### Internal APIs

Internal modules in `lua/aibo/internal/` are not part of the public API and may change without notice. If you need functionality from these modules, please open an issue to discuss making it public.

### Adding New Integrations

To add support for a new AI tool or interactive CLI:

1. Create integration module in `lua/aibo/integration/`
2. Add ftplugin file for tool-specific mappings
3. Update completion logic in command modules
4. Add tests for the integration
5. Update documentation

Example integration structure:
```lua
-- lua/aibo/integration/myai.lua
local M = {}

-- Define <Plug> mappings
M.plug_mappings = {
  ["<Plug>(aibo-myai-feature)"] = function(bufnr)
    -- Implementation
  end,
}

-- Integration-specific setup
function M.setup(bufnr, info)
  -- Setup logic
end

return M
```

## Making Changes

### Before You Start

1. Check existing issues and pull requests
2. Open an issue to discuss significant changes
3. Create a feature branch from `main`

### Development Workflow

1. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```

2. **Make changes**
   - Follow the code style guide
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes**
   ```bash
   just test
   # or manually test in Neovim
   ```

4. **Lint and format**
   ```bash
   just lint
   ```

5. **Commit with conventional commits**
   ```bash
   git commit -m "feat(integration): add support for new AI tool"
   git commit -m "fix(console): resolve buffer cleanup issue"
   git commit -m "docs: update API documentation"
   ```

### Commit Message Format

Use conventional commits:
- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `style:` Code style changes (formatting, etc.)
- `refactor:` Code refactoring
- `test:` Test additions or modifications
- `chore:` Maintenance tasks

## Submitting Pull Requests

### PR Checklist

Before submitting a PR, ensure:

- [ ] Tests pass (`just test`)
- [ ] Linting passes (`just lint`)
- [ ] Documentation is updated
- [ ] Commit messages follow conventions
- [ ] PR description clearly explains changes

### PR Process

1. **Push your branch**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create PR on GitHub**
   - Use a descriptive title
   - Reference related issues
   - Provide context and examples

3. **Address review feedback**
   - Respond to all comments
   - Push additional commits as needed
   - Request re-review when ready

4. **After merge**
   - Delete your feature branch
   - Pull latest main
   - Close related issues

## Development Workflow

### Using `just` Commands

The project includes a `justfile` with common tasks:

```bash
just check          # Run all checks (lint, format, test)
just lint           # Run luacheck
just test           # Run all tests
just test-file name # Run specific test file
just test-watch     # Run tests in watch mode
just clean          # Clean temporary files
```

### Debugging Tips

1. **Enable debug logging**
   ```lua
   vim.g.aibo_debug = true
   ```

2. **Inspect terminal output**
   ```vim
   :terminal
   ```

3. **Use vim.notify for debugging**
   ```lua
   vim.notify(vim.inspect(data), vim.log.levels.DEBUG)
   ```

4. **Check health status**
   ```vim
   :checkhealth aibo
   ```

### Common Development Tasks

#### Adding a New Command Option

1. Update `argparse.lua` if needed
2. Add option to command module
3. Update completion function
4. Add tests
5. Update documentation

#### Adding a New `<Plug>` Mapping

1. Add to appropriate integration module
2. Create ftplugin mapping
3. Document in README and help file
4. Add tests

#### Debugging Terminal Issues

1. Check `:messages` for errors
2. Inspect terminal buffer with `:ls!`
3. Use `:terminal` to test commands directly
4. Check process with `:!ps aux | grep <process>`

## Questions or Problems?

- Open an issue for bugs or feature requests
- Start a discussion for questions or ideas
- Check existing issues before creating new ones
- Provide minimal reproducible examples for bugs

Thank you for contributing to nvim-aibo!