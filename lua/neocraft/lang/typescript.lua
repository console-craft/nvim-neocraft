-- TypeScript language profile with LSP and formatter preferences.

---@type neocraft.lang.Profile
return {
  servers = {
    vtsls = {},
    eslint = {},
    biome = {},
    oxlint = {},
  },
  formatters_by_ft = {
    javascript = { project = 'javascript' },
    javascriptreact = { project = 'javascriptreact' },
    typescript = { project = 'typescript' },
    typescriptreact = { project = 'typescriptreact' },
  },
}
