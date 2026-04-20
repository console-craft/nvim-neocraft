-- Configure mini.sessions storage and behavior.

local M = {}

Lib.now(
  function()
    require('mini.sessions').setup({
      autoread = false,
      autowrite = false,
      directory = vim.fs.joinpath(vim.fn.stdpath('state'), 'sessions'),
      file = '',
      force = {
        read = false,
        write = true,
        delete = false,
      },
      verbose = {
        read = false,
        write = false,
        delete = true,
      },
    })
  end
)

return M
