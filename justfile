# nvim-aibo development tasks

# List all available tasks
default:
	@just --list

# Run luacheck and lua-language-server diagnostics
lint:
	@echo "Running luacheck..."
	@luacheck lua/ --globals vim

# Format code with stylua
fmt:
	@stylua lua/ tests/

# Run all tests
test:
	@echo "Running tests..."
	@nvim --headless -c "luafile tests/runner.lua" -c "qa!"

# Run a specific test file
test-file FILE:
	@echo "Running test: {{FILE}}"
	@nvim --headless -c "luafile tests/test_{{FILE}}.lua" -c "qa!"

# Run all checks (lint + format + test)
check: lint fmt test
