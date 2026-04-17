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
