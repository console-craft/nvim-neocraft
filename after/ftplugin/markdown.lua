vim.opt_local.conceallevel = 3
vim.opt_local.concealcursor = 'n'

if vim.bo.buftype == '' then
  vim.opt_local.colorcolumn = '+1'
  vim.opt_local.linebreak = true
  vim.opt_local.textwidth = 80
  vim.opt_local.wrap = true
end
