-- Autocommands for Neocraft

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local group = Lib.augroup('config')
local editing = require('neocraft.features.editing')
local editor = require('neocraft.features.editor')

local transient_buffers = {
  'checkhealth',
  'help',
  'lspinfo',
  'mininotify-history',
  'neocraft-lsp-clients',
  'neocraft-pack',
  'qf',
}

local function disables_spelling(filetype) return filetype == '' or vim.tbl_contains(transient_buffers, filetype) end

-- ┌───────────────────────────────────────────┐
-- │ Setup autocommands                        │
-- └───────────────────────────────────────────┘

vim.filetype.add({
  filename = {
    ['.env'] = 'sh',
  },
  pattern = {
    ['%.env%.[%w_.-]+'] = { 'sh', { priority = 10 } },
    ['docker%-compose%.ya?ml'] = 'yaml.docker-compose',
    ['compose%.ya?ml'] = 'yaml.docker-compose',
    ['.*%.component%.html'] = 'htmlangular',
    ['.*%.container%.html'] = 'htmlangular',
  },
  extension = {
    mdc = 'markdown',
  },
})

-- Highlight when yanking text
Lib.autocmd('TextYankPost', {
  group = group,
  desc = 'Highlight when yanking text',
  callback = function() vim.hl.on_yank() end,
})

-- Show inline search count
Lib.autocmd('CmdlineLeave', {
  pattern = { '/', '?' },
  group = group,
  desc = 'Show inline search count',
  callback = editing.schedule_show_inline_search_count,
})

-- Clear inline search count when search highlight is disabled
Lib.autocmd('OptionSet', {
  pattern = 'hlsearch',
  group = group,
  desc = 'Clear inline search count when search highlight is disabled',
  callback = editing.clear_inline_search_count,
})

-- Keep comment insertion conservative
Lib.autocmd('FileType', {
  group = group,
  desc = 'Keep comment insertion conservative',
  callback = function()
    vim.opt_local.formatoptions:remove('c')
    vim.opt_local.formatoptions:remove('o')
  end,
})

-- Set terminal buffer defaults
Lib.autocmd('TermOpen', {
  pattern = 'term://*',
  group = group,
  desc = 'Set terminal buffer defaults',
  callback = function(data)
    vim.bo[data.buf].bufhidden = 'hide'
    vim.bo[data.buf].buflisted = false

    vim.api.nvim_buf_call(data.buf, function()
      vim.opt_local.spell = false
      vim.opt_local.cursorline = false
    end)

    vim.schedule(function()
      if not (vim.api.nvim_get_current_buf() == data.buf and vim.bo.buftype == 'terminal') then return end
      vim.cmd('startinsert')
    end)
  end,
})

-- Update buffers when files change on disk
do
  local last_check = 0

  Lib.autocmd({ 'CursorHold', 'FocusGained', 'BufEnter', 'TermClose', 'TermLeave', 'ShellCmdPost' }, {
    group = group,
    desc = 'Update buffers when files change on disk',
    callback = function(args)
      local buf = args.buf ~= 0 and args.buf or vim.api.nvim_get_current_buf()
      if not vim.api.nvim_buf_is_valid(buf) then return end
      if vim.bo[buf].buftype ~= '' or vim.api.nvim_buf_get_name(buf) == '' then return end

      local now = vim.uv.now()
      if now - last_check < 500 then return end
      last_check = now

      pcall(vim.cmd.checktime)
    end,
  })
end

-- Notify when a file changed on disk
Lib.autocmd('FileChangedShellPost', {
  group = group,
  desc = 'Notify when a file changed on disk',
  callback = function(args)
    vim.notify(('File changed on disk: %s'):format(args.file or '(unknown)'), vim.log.levels.WARN)
  end,
})

-- Update terminal title with project and branch context
Lib.autocmd({ 'DirChanged', 'FocusGained', 'ShellCmdPost' }, {
  group = group,
  desc = 'Clear terminal title Git cache',
  callback = editor.clear_title_git_cache,
})

Lib.autocmd({ 'VimEnter', 'BufEnter', 'DirChanged', 'FocusGained', 'ShellCmdPost' }, {
  group = group,
  desc = 'Update terminal title with project and branch context',
  callback = vim.schedule_wrap(editor.update_terminal_title),
})

-- Restore cursor to last edit location
Lib.autocmd('BufReadPost', {
  group = group,
  desc = 'Restore cursor to last edit location',
  callback = function(args)
    local buf = args.buf
    if vim.bo[buf].filetype == 'gitcommit' or vim.b[buf].neocraft_last_loc then return end

    vim.b[buf].neocraft_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local line_count = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= line_count then pcall(vim.api.nvim_win_set_cursor, 0, mark) end
  end,
})

-- Resize splits when the editor is resized
Lib.autocmd('VimResized', {
  group = group,
  desc = 'Resize splits when the editor is resized',
  callback = function()
    local current_tab = vim.api.nvim_get_current_tabpage()

    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
      vim.api.nvim_set_current_tabpage(tab)
      vim.cmd.wincmd('=')
    end

    vim.api.nvim_set_current_tabpage(current_tab)
  end,
})

-- Close transient buffers with q
Lib.autocmd('FileType', {
  pattern = transient_buffers,
  group = group,
  desc = 'Close transient buffers with q',
  callback = function(args)
    vim.bo[args.buf].buflisted = false

    vim.keymap.set('n', 'q', function()
      vim.cmd.close()
      pcall(vim.api.nvim_buf_delete, args.buf, { force = true })
    end, {
      buffer = args.buf,
      silent = true,
      desc = 'Close buffer',
    })
  end,
})

-- Use Ctrl-n/p to navigate quickfix lists
Lib.autocmd('FileType', {
  pattern = 'qf',
  group = group,
  desc = 'Use Ctrl-n/p to navigate quickfix lists',
  callback = function(args)
    vim.keymap.set('n', '<C-n>', 'j', { buffer = args.buf, silent = true, desc = 'Next quickfix item' })
    vim.keymap.set('n', '<C-p>', 'k', { buffer = args.buf, silent = true, desc = 'Previous quickfix item' })
  end,
})

-- Disable spelling in transient buffers
Lib.autocmd('FileType', {
  pattern = transient_buffers,
  group = group,
  desc = 'Disable spelling in transient buffers',
  callback = function() vim.opt_local.spell = false end,
})

-- Disable spelling when non-prose buffers are shown
Lib.autocmd('BufWinEnter', {
  group = group,
  desc = 'Disable spelling when non-prose buffers are shown',
  callback = function(args)
    local win = vim.api.nvim_get_current_win()

    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= args.buf then return end

      if disables_spelling(vim.bo[args.buf].filetype) then
        vim.api.nvim_win_call(win, function() vim.opt_local.spell = false end)
      end
    end)
  end,
})

-- Create parent directories before saving files
Lib.autocmd('BufWritePre', {
  group = group,
  desc = 'Create parent directories before saving files',
  callback = function(args)
    if vim.bo[args.buf].buftype ~= '' then return end

    local path = args.file
    if path == nil or path == '' or path:match('^%w[%w+.-]*://') then return end

    local file = vim.uv.fs_realpath(path) or path
    local dir = vim.fs.dirname(file)
    if dir ~= nil and dir ~= '' then vim.fn.mkdir(dir, 'p') end
  end,
})

-- Show cursorline in the active window
Lib.autocmd({ 'BufWinEnter', 'WinEnter' }, {
  group = group,
  desc = 'Show cursorline in the active window',
  callback = function() vim.wo.cursorline = vim.bo.buftype ~= 'terminal' end,
})

-- Hide cursorline in non-active windows
Lib.autocmd('WinLeave', {
  group = group,
  desc = 'Hide cursorline in non-active windows',
  callback = function() vim.wo.cursorline = false end,
})

-- Show relative line numbers for Visual modes
Lib.autocmd('ModeChanged', {
  pattern = '*:[V\x16]*',
  group = group,
  desc = 'Show relative line numbers for Visual modes',
  callback = function() vim.wo.relativenumber = vim.wo.number end,
})

-- Hide relative line numbers for non-Visual modes
Lib.autocmd('ModeChanged', {
  pattern = '[V\x16]*:*',
  group = group,
  desc = 'Hide relative line numbers for non-Visual modes',
  callback = function() vim.wo.relativenumber = string.find(vim.fn.mode(), '^[V\22]') ~= nil end,
})

return {
  group = group,
}
