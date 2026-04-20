-- Configure mini.tabline.

local M = {}

Lib.now(function()
  local tabline = require('mini.tabline')
  local plain_label = function(label) return string.format(' %s ', label) end

  tabline.setup({
    format = function(buf_id, label)
      local name = vim.api.nvim_buf_get_name(buf_id)
      if type(name) ~= 'string' or name == '' then return plain_label(label) end

      local ok, formatted = pcall(tabline.default_format, buf_id, label)
      return ok and formatted or plain_label(label)
    end,
    show_icons = vim.g.have_nerd_font == true,
  })
end)

return M
