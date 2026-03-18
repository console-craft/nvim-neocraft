--[[--------------------------------------------------------------------------------------------------------------------

███╗   ██╗███████╗ ██████╗  ██████╗██████╗  █████╗ ███████╗████████╗
████╗  ██║██╔════╝██╔═══██╗██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝
██╔██╗ ██║█████╗  ██║   ██║██║     ██████╔╝███████║█████╗     ██║
██║╚██╗██║██╔══╝  ██║   ██║██║     ██╔══██╗██╔══██║██╔══╝     ██║
██║ ╚████║███████╗╚██████╔╝╚██████╗██║  ██║██║  ██║██║        ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝

Personal Neovim `0.12+` configuration focused on explicit structure, native APIs, and a mini-first UX.

Created by Ovi Ispas <ovi@console-craft.com>

----------------------------------------------------------------------------------------------------------------------]]

if vim.fn.has('nvim-0.12') == 0 then error('Neocraft requires Neovim 0.12+') end

_G.Lib = require('neocraft.core.helpers')

require('neocraft.config.options')
require('neocraft.config.autocmds')
require('neocraft.config.keymaps')

require('neocraft.core.root')
require('neocraft.core.sessions')
require('neocraft.core.pack')

require('neocraft.plugins.mini')
require('neocraft.plugins.treesitter')
require('neocraft.plugins.lsp')
require('neocraft.plugins.format')
require('neocraft.plugins.git')
