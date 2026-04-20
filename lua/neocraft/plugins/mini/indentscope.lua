-- Configure mini.indentscope and disable it in prose and special buffers.

local M = {}

local prose_filetypes = {
  'gitcommit',
  'markdown',
  'text',
}

local function is_prose_buffer(buf) return vim.tbl_contains(prose_filetypes, vim.bo[buf].filetype) end

Lib.later(function()
  local indentscope = require('mini.indentscope')
  indentscope.setup({
    symbol = '│',
    draw = {
      delay = 0,
      animation = indentscope.gen_animation.linear({ duration = 125, unit = 'total' }),
    },
    options = {
      try_as_border = true,
    },
  })

  local function refresh_indentscope_disable(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    vim.b[bufnr].miniindentscope_disable = vim.bo[bufnr].buftype ~= '' or is_prose_buffer(bufnr)
  end

  Lib.autocmd({ 'FileType', 'BufWinEnter', 'TermOpen' }, {
    group = Lib.augroup('mini_indentscope'),
    desc = 'Disable mini.indentscope in prose and special buffers',
    callback = function(args) refresh_indentscope_disable(args.buf) end,
  })

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    refresh_indentscope_disable(bufnr)
  end
end)

return M
