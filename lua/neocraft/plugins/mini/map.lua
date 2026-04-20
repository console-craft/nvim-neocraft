-- Configure mini.map.

local M = {}

Lib.later(function()
  local map = require('mini.map')

  map.setup({
    symbols = {
      encode = map.gen_encode_symbols.dot('4x2'),
      scroll_line = '┃',
      scroll_view = '│',
    },
    integrations = {
      map.gen_integration.builtin_search(),
      map.gen_integration.diff(),
    },
    window = {
      focusable = true,
      width = 5,
      winblend = 15,
      show_integration_count = false,
      zindex = 50,
    },
  })

  map.open()
end)

return M
