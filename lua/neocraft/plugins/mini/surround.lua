-- Configure mini.surround and related key aliases.

local M = {}

Lib.later(function()
  require('mini.surround').setup({
    mappings = {
      add = 'ys',
      delete = 'ds',
      find = '',
      find_left = '',
      highlight = '',
      replace = 'cs',
      suffix_last = '',
      suffix_next = '',
    },
    search_method = 'cover',
  })

  vim.keymap.del('x', 'ys')
  vim.keymap.set('x', 'S', [[:<C-u>lua MiniSurround.add('visual')<CR>]], {
    desc = 'Add surrounding to selection',
    silent = true,
  })

  vim.keymap.set('n', 'yss', 'ys_', {
    desc = 'Add surrounding to line',
    remap = true,
    silent = true,
  })
end)

return M
