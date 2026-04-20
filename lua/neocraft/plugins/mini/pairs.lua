-- Configure mini.pairs and disable it in prose buffers.

local M = {}

local prose_filetypes = {
  'gitcommit',
  'markdown',
  'text',
}

local function is_prose_buffer(buf) return vim.tbl_contains(prose_filetypes, vim.bo[buf].filetype) end

Lib.later(function()
  require('mini.pairs').setup({ modes = { command = true } })

  local function disable_minipairs_in_prose(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    if is_prose_buffer(bufnr) then vim.b[bufnr].minipairs_disable = true end
  end

  local mini_group = Lib.augroup('mini')
  Lib.autocmd('FileType', {
    group = mini_group,
    pattern = prose_filetypes,
    desc = 'Disable mini.pairs in prose buffers',
    callback = function(args) vim.b[args.buf].minipairs_disable = true end,
  })

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    disable_minipairs_in_prose(bufnr)
  end
end)

return M
