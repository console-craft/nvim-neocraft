-- Configure mini.nvim modules and expose Neocraft's mini-powered helpers.

local M = {}

local pack = require('neocraft.core.pack')

-- ┌───────────────────────────────────────────┐
-- │ Install mini.nvim                         │
-- └───────────────────────────────────────────┘

pack.add('mini', {
  { src = 'https://github.com/nvim-mini/mini.nvim' },
})

-- ┌───────────────────────────────────────────┐
-- │ Setup Mini plugins                        │
-- └───────────────────────────────────────────┘

-- Base editor UI
require('neocraft.plugins.mini.notify')
require('neocraft.plugins.mini.icons')
require('neocraft.plugins.mini.statusline')
require('neocraft.plugins.mini.tabline')
require('neocraft.plugins.mini.clue')
require('neocraft.plugins.mini.map')
require('neocraft.plugins.mini.animate')
require('neocraft.plugins.mini.extra')

-- Editing & motion
require('neocraft.plugins.mini.ai')
require('neocraft.plugins.mini.surround')
require('neocraft.plugins.mini.jump2d')

-- Coding
require('neocraft.plugins.mini.completion')
require('neocraft.plugins.mini.indentscope')
require('neocraft.plugins.mini.cursorword')
require('neocraft.plugins.mini.pairs')
require('neocraft.plugins.mini.hipatterns') -- TODO: add better comments later

-- State management
require('neocraft.plugins.mini.bufremove')
require('neocraft.plugins.mini.sessions')
require('neocraft.plugins.mini.visits')

-- Navigation
require('neocraft.plugins.mini.files')
require('neocraft.plugins.mini.pick')

return M
