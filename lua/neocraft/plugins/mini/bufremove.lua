-- Configure mini.bufremove and related user commands.

local M = {}

Lib.later(function() require('mini.bufremove').setup() end)

return M
