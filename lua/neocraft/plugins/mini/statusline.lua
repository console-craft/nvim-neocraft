-- Configure mini.statusline.

local M = {}

Lib.now(function()
  local statusline = require('mini.statusline')
  statusline.setup({ use_icons = vim.g.have_nerd_font == true })

  statusline.section_location = function() return '%2l:%-2v' end
end)

return M
