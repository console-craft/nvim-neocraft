-- Configure mini.ai.

local M = {}

Lib.later(function()
  local ai = require('mini.ai')
  local mini_extra = require('mini.extra')
  ai.setup({
    custom_textobjects = {
      B = mini_extra.gen_ai_spec.buffer(),
      F = ai.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),
    },
    search_method = 'cover',
  })
end)

return M
