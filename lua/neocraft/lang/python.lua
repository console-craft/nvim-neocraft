-- Python language profile with LSP, tools, and formatter preferences.

---@type neocraft.lang.Profile
return {
  servers = {
    basedpyright = {},
    ruff = {},
  },
  tools = {
    'black',
    'isort',
  },
  formatters_by_ft = {
    python = { project = 'python', fallback = { 'isort', 'black' } },
  },
}
