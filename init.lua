-- ┌───────────────────────────────────────────────────────────────────────────┐
-- │                                                                           │
-- │   ███╗   ██╗███████╗ ██████╗  ██████╗██████╗  █████╗ ███████╗████████╗    │
-- │   ████╗  ██║██╔════╝██╔═══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝    │
-- │   ██╔██╗ ██║█████╗  ██║   ██║██║     ██████╔╝███████║█████╗     ██║       │
-- │   ██║╚██╗██║██╔══╝  ██║   ██║██║     ██╔══██╗██╔══██║██╔══╝     ██║       │
-- │   ██║ ╚████║███████╗╚██████╔╝╚██████╗██║  ██║██║  ██║██║        ██║       │
-- │   ╚═╝  ╚═══╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝       │
-- │                                                                           │
-- │   Personal Neovim `0.12+` configuration focused on explicit structure,    │
-- │                   native APIs, and a mini-first UX.                       │
-- │                                                                           │
-- │                                v1.0.0                                     │
-- │                                                                           │
-- │             Created by Ovi Ispas <ovi@console-craft.com>                  │
-- │                                                                           │
-- └───────────────────────────────────────────────────────────────────────────┘

if vim.fn.has('nvim-0.12') == 0 then error('Neocraft requires Neovim 0.12+') end

_G.Lib = require('neocraft.core.helpers')

-- ┌───────────────────────────────────────────┐
-- │ Config                                    │
-- └───────────────────────────────────────────┘

require('neocraft.config.options')
require('neocraft.config.autocmds')
require('neocraft.config.keymaps')

-- ┌───────────────────────────────────────────┐
-- │ Helper modules                            │
-- └───────────────────────────────────────────┘

require('neocraft.core.pack')
require('neocraft.core.root')
require('neocraft.core.sessions')

-- ┌───────────────────────────────────────────┐
-- │ Plugins                                   │
-- └───────────────────────────────────────────┘

require('neocraft.plugins.mini')
require('neocraft.plugins.ui')
require('neocraft.plugins.treesitter')
require('neocraft.plugins.lsp')
require('neocraft.plugins.conform')
require('neocraft.plugins.git')

-- ┌───────────────────────────────────────────┐
-- │ Features                                  │
-- └───────────────────────────────────────────┘

require('neocraft.features.mini')
require('neocraft.features.treesitter')
require('neocraft.features.completions')
require('neocraft.features.terminal')

-- ┌───────────────────────────────────────────┐
-- │ Theme                                     │
-- └───────────────────────────────────────────┘

vim.cmd.colorscheme('gruvcraft-dark')
