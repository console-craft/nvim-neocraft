local function is_github_actions_file(bufnr)
  local path = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
  return path:find('/.github/workflows/', 1, true) ~= nil
end

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
