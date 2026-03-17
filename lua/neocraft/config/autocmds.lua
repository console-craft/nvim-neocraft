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

return {
  group = group,
}
