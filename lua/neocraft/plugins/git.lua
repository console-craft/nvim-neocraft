-- Configure Git-related plugins and expose Neocraft's Git helpers.

local M = {}

local pack = require('neocraft.core.pack')

-- ┌───────────────────────────────────────────┐
-- │ Install plugins                           │
-- └───────────────────────────────────────────┘

pack.add('git', {
  { src = 'https://github.com/nvim-lua/plenary.nvim' },
  { src = 'https://github.com/sindrets/diffview.nvim' },
})

-- ┌───────────────────────────────────────────┐
-- │ Setup plugins                             │
-- └───────────────────────────────────────────┘

-- Configure mini.diff.
Lib.later(function()
  vim.api.nvim_set_hl(0, 'NeocraftMiniDiffCount', { default = true, link = 'MiniDiffSignChange' })

  require('mini.diff').setup({
    mappings = {
      goto_first = '',
      goto_prev = '',
      goto_next = '',
      goto_last = '',
    },
    view = {
      style = 'sign',
      signs = {
        add = '▎',
        change = '▎',
        delete = '▎',
      },
    },
    options = {
      wrap_goto = true,
      algorithm = 'patience',
      indent_heuristic = false,
      linematch = 0,
    },
  })
end)

-- Configure mini.git.
Lib.later(function() require('mini.git').setup() end)

-- Configure diffview.nvim.
Lib.later(function()
  local diffview = require('neocraft.features.git.diffview')

  require('diffview').setup({
    enhanced_diff_hl = true,
    hooks = diffview.hooks(),
    keymaps = diffview.keymaps(),
  })
end)

-- Ensure mini.clue triggers in Git output buffers.
Lib.autocmd('User', {
  group = Lib.augroup('git'),
  pattern = 'MiniGitCommandSplit',
  desc = 'Ensure mini.clue triggers in Git output buffers',
  callback = function(args)
    local data = args.data or {}
    local win = data.win_stdout
    if type(win) ~= 'number' or not vim.api.nvim_win_is_valid(win) then return end

    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(win) then return end

      local ok, clue = pcall(require, 'mini.clue')
      if not ok then return end

      clue.ensure_buf_triggers(vim.api.nvim_win_get_buf(win))
    end)
  end,
})

return M
