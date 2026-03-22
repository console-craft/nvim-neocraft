local group = Lib.augroup('config')

Lib.autocmd('TextYankPost', {
  group = group,
  desc = 'Highlight when yanking text',
  callback = function() vim.hl.on_yank() end,
})

Lib.autocmd('FileType', {
  group = group,
  desc = 'Keep comment insertion conservative',
  callback = function()
    vim.opt_local.formatoptions:remove('c')
    vim.opt_local.formatoptions:remove('o')
  end,
})

Lib.autocmd('TermOpen', {
  pattern = 'term://*',
  group = group,
  desc = 'Start builtin terminal in Insert mode',
  callback = function(data)
    vim.schedule(function()
      if not (vim.api.nvim_get_current_buf() == data.buf and vim.bo.buftype == 'terminal') then return end
      vim.cmd('startinsert')
    end)
  end,
})

Lib.autocmd('ModeChanged', {
  pattern = '*:[V\x16]*',
  group = group,
  callback = function() vim.wo.relativenumber = vim.wo.number end,
  desc = 'Show relative line numbers for Visual modes',
})

Lib.autocmd('ModeChanged', {
  pattern = '[V\x16]*:*',
  group = group,
  desc = 'Hide relative line numbers for non-Visual modes',
  callback = function() vim.wo.relativenumber = string.find(vim.fn.mode(), '^[V\22]') ~= nil end,
})

return {
  group = group,
}
