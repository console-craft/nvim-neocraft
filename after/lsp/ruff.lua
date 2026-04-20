-- Overrides settings from the default ruff LSP config provided by nvim-lspconfig.
--
--  * Disables Ruff's hover provider so Basedpyright remains the single hover source in Python buffers.
--  * Keeps Ruff attached for lint diagnostics and Python-specific code actions such as organize imports.
--  * Leaves the rest of the Ruff server setup to upstream defaults.
--
-- DOCS: https://github.com/neovim/nvim-lspconfig/blob/master/lsp/ruff.lua

-- ┌───────────────────────────────────────────┐
-- │ LSP config                                │
-- └───────────────────────────────────────────┘

return {
  on_attach = function(client) client.server_capabilities.hoverProvider = false end,
}
