-- Configure mini.jump2d.

local M = {}

Lib.later(function()
  local jump2d = require('mini.jump2d')
  jump2d.setup({
    mappings = {
      start_jumping = 's',
    },
    spotter = jump2d.builtin_opts.word_start.spotter,
    allowed_windows = {
      not_current = false,
    },
    allowed_lines = {
      blank = false,
    },
    silent = true,
  })
end)

return M
