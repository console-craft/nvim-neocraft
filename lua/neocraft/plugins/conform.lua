-- Sets up conform.nvim with project-aware formatter resolution based on configuration files.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local pack = require('neocraft.core.pack')
local lang = require('neocraft.lang')
local formatting = require('neocraft.features.formatting')

---@type neocraft.formatting.Opts
local opts = {
  formatter_order = { 'prettier', 'oxfmt', 'biome', 'ruff' },
  formatter_support = {
    prettier = {
      javascript = true,
      javascriptreact = true,
      json = true,
      jsonc = true,
      markdown = true,
      toml = true,
      typescript = true,
      typescriptreact = true,
      yaml = true,
      ['yaml.docker-compose'] = true,
    },
    oxfmt = {
      javascript = true,
      javascriptreact = true,
      json = true,
      jsonc = true,
      markdown = true,
      toml = true,
      typescript = true,
      typescriptreact = true,
      yaml = true,
      ['yaml.docker-compose'] = true,
    },
    biome = {
      javascript = true,
      javascriptreact = true,
      json = true,
      jsonc = true,
      typescript = true,
      typescriptreact = true,
    },
    ruff = {
      python = true,
    },
  },
  markers_by_formatter = {
    prettier = {
      '.prettierrc',
      '.prettierrc.json',
      '.prettierrc.yml',
      '.prettierrc.yaml',
      '.prettierrc.json5',
      '.prettierrc.js',
      '.prettierrc.cjs',
      '.prettierrc.mjs',
      '.prettierrc.toml',
      'prettier.config.js',
      'prettier.config.cjs',
      'prettier.config.mjs',
    },
    oxfmt = {
      '.oxfmtrc.json',
      '.oxfmtrc.jsonc',
    },
    biome = {
      'biome.json',
      'biome.jsonc',
      '.biome.json',
      '.biome.jsonc',
    },
    ruff = {
      'ruff.toml',
      '.ruff.toml',
      'pyproject.toml',
    },
  },
}

local disable_format_on_save = {
  gitcommit = true,
  markdown = true,
  text = true,
}

-- ┌───────────────────────────────────────────┐
-- │ Install and setup Conform                 │
-- └───────────────────────────────────────────┘

pack.add('format', {
  { src = 'https://github.com/stevearc/conform.nvim' },
})

Lib.now(function()
  require('conform').setup({
    default_format_opts = {
      lsp_format = 'fallback',
      timeout_ms = 3000,
    },
    format_on_save = function(bufnr)
      if vim.g.enable_format_on_save ~= true then return nil end
      if vim.bo[bufnr].buftype ~= '' then return nil end

      if disable_format_on_save[vim.bo[bufnr].filetype] then return nil end

      return {
        timeout_ms = 3000,
        lsp_format = 'fallback',
      }
    end,
    notify_on_error = true,
    formatters = {
      project_prettierd = {
        inherit = 'prettierd',
        cwd = function(_, ctx) return formatting.get_formatter_root(ctx.buf, 'prettier', opts) end,
        require_cwd = true,
      },
      project_prettier = {
        inherit = 'prettier',
        cwd = function(_, ctx) return formatting.get_formatter_root(ctx.buf, 'prettier', opts) end,
        require_cwd = true,
      },
      project_oxfmt = {
        inherit = 'oxfmt',
        cwd = function(_, ctx) return formatting.get_formatter_root(ctx.buf, 'oxfmt', opts) end,
        require_cwd = true,
      },
      project_biome = {
        inherit = 'biome',
        cwd = function(_, ctx) return formatting.get_formatter_root(ctx.buf, 'biome', opts) end,
        require_cwd = true,
      },
      project_ruff_organize_imports = {
        inherit = 'ruff_organize_imports',
        cwd = function(_, ctx) return formatting.get_formatter_root(ctx.buf, 'ruff', opts) end,
        require_cwd = true,
      },
      project_ruff_format = {
        inherit = 'ruff_format',
        cwd = function(_, ctx) return formatting.get_formatter_root(ctx.buf, 'ruff', opts) end,
        require_cwd = true,
      },
    },
    formatters_by_ft = formatting.get_formatters_by_ft(lang.formatters_by_ft, opts),
  })
end)

return M
