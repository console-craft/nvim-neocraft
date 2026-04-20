-- Overrides settings from the default eslint LSP config provided by `nvim-lspconfig`.
--
--  * Disables ESLint formatting so JavaScript and TypeScript formatting stays in the dedicated formatter pipeline.
--  * Disables ESLint code actions on save to avoid automatic fix-all passes from the LSP client.
--  * Lets ESLint infer working directories automatically for multi-package and monorepo layouts.
--
-- DOCS: https://github.com/neovim/nvim-lspconfig/blob/master/lsp/eslint.lua

-- ┌───────────────────────────────────────────┐
-- │ LSP config                                │
-- └───────────────────────────────────────────┘

return {
  settings = {
    codeActionOnSave = {
      enable = false,
      mode = 'all',
    },
    format = false,
    workingDirectories = {
      mode = 'auto',
    },
  },
}
