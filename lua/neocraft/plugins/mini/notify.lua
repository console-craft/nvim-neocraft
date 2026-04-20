-- Configure mini.notify as the default notification UI.

local M = {}

Lib.now(function()
  local mini_notify = require('mini.notify')
  mini_notify.setup()

  vim.notify = mini_notify.make_notify({
    ERROR = { duration = 5000 },
    WARN = { duration = 2500 },
    INFO = { duration = 2500 },
    DEBUG = { duration = 2500 },
  })
end)

return M
