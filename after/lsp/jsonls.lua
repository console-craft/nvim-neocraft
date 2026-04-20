-- Overrides settings from the default jsonls LSP config provided by `nvim-lspconfig`.
--
--  * Keeps built-in JSON formatting available when the server is asked to format.
--  * Loads SchemaStore's JSON schema catalog for schema-aware completion and validation.
--  * Keeps JSON validation enabled.
--
-- DOCS: https://github.com/neovim/nvim-lspconfig/blob/master/lsp/jsonls.lua

-- ┌───────────────────────────────────────────┐
-- │ LSP config                                │
-- └───────────────────────────────────────────┘

return {
  settings = {
    json = {
      format = {
        enable = true,
      },
      schemas = require('schemastore').json.schemas(),
      validate = {
        enable = true,
      },
    },
  },
}
