-- Overrides settings from the default basedpyright LSP config provided by nvim-lspconfig.
--
--  * Disables Basedpyright's organize-imports command so Python import cleanup stays with Ruff and the formatter pipeline.
--  * Enables auto-import completions and automatic search-path discovery.
--  * Limits analysis to open buffers to keep diagnostics focused and lightweight.
--
-- DOCS: https://github.com/neovim/nvim-lspconfig/blob/master/lsp/basedpyright.lua

-- ┌───────────────────────────────────────────┐
-- │ LSP config                                │
-- └───────────────────────────────────────────┘

return {
  settings = {
    basedpyright = {
      disableOrganizeImports = true,
      analysis = {
        autoImportCompletions = true,
        autoSearchPaths = true,
        diagnosticMode = 'openFilesOnly',
      },
    },
  },
}
