-- Prose related defaults for Git commit messages.

-- stylua: ignore start
vim.opt_local.formatexpr      = ''    -- Use built-in formatting instead of external formatters
vim.opt_local.textwidth       = 80    -- Set a default text width for formatting and visual indication of line length
vim.opt_local.colorcolumn     = '+1'  -- Highlight the column after the textwidth to visually indicate line length limit
vim.opt_local.wrap            = true  -- Enable visual line wrapping by default
vim.opt_local.linebreak       = true  -- Wrap at word boundaries when wrapping is enabled
-- stylua: ignore end
