-- Prose related defaults for Markdown files.

-- NOTE: Conceal behavior is managed by the `render-markdown` plugin which sets:
--  * vim.opt_local.conceallevel = 3
--  * vim.opt_local.concealcursor = 'n'

-- Only apply these settings to real file buffers, not `mini.completion` previews or special Markdown views.
if vim.bo.buftype == '' then
  -- stylua: ignore start
  vim.opt_local.textwidth       = 80    -- Set a default text width for formatting and visual indication of line length
  vim.opt_local.colorcolumn     = '+1'  -- Highlight the column after the textwidth to visually indicate line length limit
  vim.opt_local.wrap            = true  -- Enable visual line wrapping by default
  vim.opt_local.linebreak       = true  -- Wrap at word boundaries when wrapping is enabled
  -- stylua: ignore end
end
