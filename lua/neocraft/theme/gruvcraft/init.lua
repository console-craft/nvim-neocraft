-- Gruvcraft theme entrypoint with variant resolution and grouped highlight setup.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local palette = require('neocraft.theme.gruvcraft.palette')
local syntax = require('neocraft.theme.gruvcraft.syntax')
local editor = require('neocraft.theme.gruvcraft.editor')
local plugins = require('neocraft.theme.gruvcraft.plugins')
local runtime = require('neocraft.theme.runtime')

-- Return the theme specification for a given variant, asserting that the variant exists.
---@param variant string
---@return neocraft.theme.Spec
local function get_spec(variant)
  local spec = palette.variants[variant]
  assert(spec ~= nil, string.format("Unknown gruvcraft variant '%s'", tostring(variant)))
  return spec
end

-- ┌───────────────────────────────────────────┐
-- │ Apply theme variant                       │
-- └───────────────────────────────────────────┘

-- Apply a theme variant by setting up the base16 palette, syntax highlights, highlight groups and the colorscheme name.
---@param variant string
function M.apply(variant)
  local spec = get_spec(variant)

  require('mini.base16').setup({
    palette = palette.base16_palette(spec.colors),
    use_cterm = true,
    plugins = { default = true },
  })

  syntax.setup(spec)
  editor.setup(spec)
  plugins.setup(spec)
  runtime.setup(spec)

  vim.g.colors_name = spec.name
end

return M
