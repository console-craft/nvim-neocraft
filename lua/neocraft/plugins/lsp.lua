-- Configure Neovim LSP, Mason tooling, and language-specific helpers.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local pack = require('neocraft.core.pack')
local lang = require('neocraft.lang')
local attach = require('neocraft.features.lsp.attach')
local annotations = require('neocraft.features.lsp.annotations')
local copilot = require('neocraft.features.lsp.copilot')
local typescript = require('neocraft.features.lsp.typescript')
local python = require('neocraft.features.lsp.python')

-- Returns capabilities related to file operations, such as renaming files.
local function file_operation_capabilities()
  return {
    workspace = {
      fileOperations = {
        didRename = true,
        willRename = true,
      },
    },
  }
end

-- Combines capabilities for file operations and any additional capabilities from the completion plugin.
local function lsp_capabilities()
  return vim.tbl_deep_extend('force', file_operation_capabilities(), require('mini.completion').get_lsp_capabilities())
end

-- Returns a list of LSP server names to ensure are installed, based on the configured language servers.
local function server_names() return vim.tbl_keys(lang.servers) end

-- Returns a list of tools to ensure are installed, combining LSP servers and language-specific tools.
local function ensure_installed() return vim.list_extend(server_names(), vim.deepcopy(lang.tools)) end

-- ┌───────────────────────────────────────────┐
-- │ Install LSP related plugins               │
-- └───────────────────────────────────────────┘

pack.add('lsp', {
  { src = 'https://github.com/mason-org/mason.nvim' },
  { src = 'https://github.com/mason-org/mason-lspconfig.nvim' },
  { src = 'https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim' },
  { src = 'https://github.com/neovim/nvim-lspconfig' },
  { src = 'https://github.com/b0o/SchemaStore.nvim' },
  { src = 'https://github.com/linux-cultist/venv-selector.nvim' },
  { src = 'https://gitlab.com/schrieveslaach/sonarlint.nvim' },
})

-- ┌───────────────────────────────────────────┐
-- │ Setup plugins                             │
-- └───────────────────────────────────────────┘

Lib.now(function()
  require('neocraft.features.lsp.rename')

  require('mason').setup({
    ui = {
      icons = {
        package_installed = '✓',
        package_pending = '➜',
        package_uninstalled = '✗',
      },
      border = vim.o.winborder,
    },
  })

  require('mason-tool-installer').setup({
    ensure_installed = ensure_installed(),
  })

  require('venv-selector').setup({
    options = {
      notify_user_on_venv_activation = false,
      picker = 'mini-pick',
      require_lsp_activation = true,
    },
  })

  -- Configure and enable LSP servers

  vim.lsp.config('*', {
    capabilities = lsp_capabilities(),
  })

  for _, name in ipairs(server_names()) do
    vim.lsp.config(name, lang.servers[name])
    vim.lsp.enable(name)
  end
end)

attach.setup({
  annotations = annotations,
  copilot = copilot,
  typescript = typescript,
  python = python,
})

return M
