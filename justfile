# Aibo development tasks

# List all available tasks
default:
	@just --list

# Run luacheck and lua-language-server diagnostics
lint:
	echo "Running luacheck..."
	luacheck lua/ --globals vim

# Format code with stylua
fmt:
	stylua lua/ tests/

# Run all tests
test:
	nvim --headless --noplugin -u ./tests/minimal_init.lua -c "lua MiniTest.run()"

# Run a specific test file
test-file FILE:
	nvim --headless --noplugin -u ./tests/minimal_init.lua -c "lua MiniTest.run_file('{{FILE}}')"

deps-mini-nvim:
  @mkdir -p .deps
  @git clone --filter=blob:none https://github.com/nvim-mini/mini.nvim .deps/mini.nvim

# Run all checks (lint + format + test)
check: lint fmt test
