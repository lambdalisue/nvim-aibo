-- Luacheck configuration for nvim-aibo

std = "lua51"
cache = true
codes = true

-- Neovim globals
read_globals = {
  "vim",
}

-- Plugin-specific globals
globals = {
  -- Add any plugin-specific globals here if needed
}

-- Ignore some warnings
ignore = {
  "122", -- Setting read-only field (false positive for vim.bo, vim.wo, vim.b in Neovim)
  "631", -- Line too long
}

-- Set max line length
max_line_length = 120

-- Configure specific files
files = {
  ["lua/**/*.lua"] = {
    std = "+busted",
  },
  ["plugin/**/*.lua"] = {
    std = "+busted",
  },
  ["ftplugin/**/*.lua"] = {
    std = "+busted",
  },
}
