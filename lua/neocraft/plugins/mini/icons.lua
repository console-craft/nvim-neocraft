-- Configure mini.icons and related icon integrations.

local M = {}

Lib.now(function()
  local mini_icons = require('mini.icons')
  local ext3_blocklist = { scm = true, txt = true, yml = true }
  local ext4_blocklist = { json = true, yaml = true }
  mini_icons.setup({
    use_file_extension = function(ext, _) return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)]) end,
  })

  Lib.later(mini_icons.mock_nvim_web_devicons)
  Lib.later(mini_icons.tweak_lsp_kind)
end)

return M
