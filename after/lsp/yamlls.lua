-- Overrides settings from the default yamlls LSP config provided by nvim-lspconfig.
--
--  * Enables line-only folding, formatting, and validation for general YAML buffers.
--  * Uses SchemaStore via `schemastore.nvim`, disables the server's built-in schema store, and leaves key ordering alone.
--  * Detaches from GitHub Actions and Docker Compose YAML so their specialized language servers can own those files.
--
-- DOCS: https://github.com/neovim/nvim-lspconfig/blob/master/lsp/yamlls.lua

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local function is_github_actions_file(bufnr)
  local path = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
  return path:find('/.github/workflows/', 1, true) ~= nil
end

-- ┌───────────────────────────────────────────┐
-- │ LSP config                                │
-- └───────────────────────────────────────────┘

return {
  capabilities = {
    textDocument = {
      foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly = true,
      },
    },
  },
  settings = {
    redhat = {
      telemetry = {
        enabled = false,
      },
    },
    yaml = {
      format = {
        enable = true,
      },
      keyOrdering = false,
      schemaStore = {
        enable = false,
        url = '',
      },
      schemas = require('schemastore').yaml.schemas(),
      validate = true,
    },
  },
  on_attach = function(client, bufnr)
    -- Let specialized workflow and compose servers own those YAML subtypes.
    if vim.bo[bufnr].filetype == 'yaml.docker-compose' or is_github_actions_file(bufnr) then
      vim.schedule(function() vim.lsp.buf_detach_client(bufnr, client.id) end)
    end
  end,
}
