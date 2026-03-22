local pack = require('neocraft.core.pack')
local keymaps = require('neocraft.config.keymaps')

local use_icons = vim.g.have_nerd_font == true

pack.add('mini', {
  { src = 'https://github.com/nvim-mini/mini.nvim' },
})

-- ┌───────────────────────────────────────────┐
-- │ mini.icons                                │
-- └───────────────────────────────────────────┘

Lib.now(function()
  local mini_icons = require('mini.icons')
  local ext3_blocklist = { scm = true, txt = true, yml = true }
  local ext4_blocklist = { json = true, yaml = true }
  mini_icons.setup({
    -- Set up to not prefer extension-based icon for some extensions
    use_file_extension = function(ext, _) return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)]) end,
  })

  Lib.later(mini_icons.mock_nvim_web_devicons)
  Lib.later(mini_icons.tweak_lsp_kind)
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.notify                               │
-- └───────────────────────────────────────────┘

Lib.now(function()
  local mini_notify = require('mini.notify')
  mini_notify.setup()

  vim.notify = mini_notify.make_notify({
    -- Keep errors at default duration, decrease the rest, show debug messages
    ERROR = { duration = 5000 },
    WARN = { duration = 2500 },
    INFO = { duration = 2500 },
    DEBUG = { duration = 2500 },
  })
end)

vim.api.nvim_create_user_command('NeocraftNotifications', function() require('mini.notify').show_history() end, {
  desc = 'Show Neocraft notification history',
})

vim.api.nvim_create_user_command('NeocraftNotificationsClear', function() require('mini.notify').clear() end, {
  desc = 'Clear Neocraft visible notifications',
})

-- ┌───────────────────────────────────────────┐
-- │ mini.statusline                           │
-- └───────────────────────────────────────────┘

Lib.now(function()
  local statusline = require('mini.statusline')
  statusline.setup({ use_icons = use_icons })

  statusline.section_location = function() return '%2l:%-2v' end
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.tabline                              │
-- └───────────────────────────────────────────┘

Lib.now(function() require('mini.tabline').setup() end)

-- ┌───────────────────────────────────────────┐
-- │ mini.clue                                 │
-- └───────────────────────────────────────────┘

Lib.later(function()
  local clue = require('mini.clue')
  clue.setup({
    clues = {
      keymaps.leader_group_clues,
      clue.gen_clues.builtin_completion(),
      clue.gen_clues.g(),
      clue.gen_clues.marks(),
      clue.gen_clues.registers(),
      clue.gen_clues.square_brackets(),
      clue.gen_clues.windows({ submode_resize = true }),
      clue.gen_clues.z(),
    },
    triggers = {
      { mode = { 'n', 'x' }, keys = '<Leader>' },
      { mode = 'n', keys = [[\]] },
      { mode = { 'n', 'x' }, keys = '[' },
      { mode = { 'n', 'x' }, keys = ']' },
      { mode = 'i', keys = '<C-x>' },
      { mode = { 'n', 'x' }, keys = 'g' },
      { mode = { 'n', 'x' }, keys = "'" },
      { mode = { 'n', 'x' }, keys = '`' },
      { mode = { 'n', 'x' }, keys = '"' },
      { mode = { 'i', 'c' }, keys = '<C-r>' },
      { mode = 'n', keys = '<C-w>' },
      { mode = { 'n', 'x' }, keys = 'z' },
    },
    window = {
      delay = 200,
      config = { width = 'auto' },
    },
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.ai                                   │
-- └───────────────────────────────────────────┘

-- Example usage for mini.ai:
--  * ciq - [c]hange [i]nside [q]uotes
--  * di( - [d]elete [i]nside `(`
--  * yina - [y]ank [i]nside [n]ext [a]rgument
--  * yit - [y]ank [i]nside [t]ag
--  * vab - [v]isually select [a]round brackets (including object/array delimiters)
--  * viB - [v]isually select [i]nside [B]uffer (excluding trailing newlines)
--  * vif - [v]isually select [i]nside [f]unction call (function call arguments)
--  * vaf - [v]isually select [a]round [f]unction call (whole function call)
--  * yiF - [y]ank [i]nside [F]unction definition (function definition content)
--  * yaF - [y]ank [a]round [F]unction definition (whole function definition)
Lib.later(function()
  local ai = require('mini.ai')
  local mini_extra = require('mini.extra')
  ai.setup({
    custom_textobjects = {
      -- Make `aB` / `iB` act on around/inside whole [B]uffer
      B = mini_extra.gen_ai_spec.buffer(),
      -- Make `aF`/`iF` act on around/inside function definition (not call)
      F = ai.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),
    },
    search_method = 'cover',
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.jump2d                               │
-- └───────────────────────────────────────────┘

Lib.later(function()
  require('mini.jump2d').setup({
    mappings = {
      start_jumping = 's',
    },
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.surround                             │
-- └───────────────────────────────────────────┘

-- Example usage for mini.surround:
--  * ysiw{char}             - [y]es [s]urround [i]nside [w]ord with {char}
--  * ysawt -> {tag}         - [y]es [s]urround [a]round [w]ord with [t]ag {tag}
--  * yassq                  - [y]es [s]urround [s]entence (ss = line) with [q]uotes
--  * ds{char}               - [d]elete [s]urrounding {char}
--  * cs{char}{replacement}  - [c]hange [s]urrounding {char} with {replacement}
--  * S (Visual mode)        - [S]urround current selection
Lib.later(function()
  require('mini.surround').setup({
    mappings = {
      add = 'ys',
      delete = 'ds',
      find = '',
      find_left = '',
      highlight = '',
      replace = 'cs',
      suffix_last = '',
      suffix_next = '',
    },
    search_method = 'cover',
  })

  -- S in Visual mode is a common convenience. Also delete `ys` from Visual mode (since its accompanying `ds`/`cs` don't exist in Visual mode anyway)
  vim.keymap.del('x', 'ys')
  vim.keymap.set('x', 'S', [[:<C-u>lua MiniSurround.add('visual')<CR>]], {
    desc = 'Add surrounding to selection',
    silent = true,
  })

  -- Alias the common `yss` ("yes surround sentence / line") to mini.surround's `ys_`
  vim.keymap.set('n', 'yss', 'ys_', {
    desc = 'Add surrounding to line',
    remap = true,
    silent = true,
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.pairs                                │
-- └───────────────────────────────────────────┘

-- Note: use <C-v>( to insert a literal single part of the pair
Lib.later(function()
  require('mini.pairs').setup({ modes = { command = true } })

  local prose_filetypes = {
    'asciidoc',
    'gitcommit',
    'markdown',
    'norg',
    'org',
    'plaintex',
    'rst',
    'tex',
    'text',
  }

  local function disable_minipairs_in_prose(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    if vim.tbl_contains(prose_filetypes, vim.bo[bufnr].filetype) then vim.b[bufnr].minipairs_disable = true end
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

-- ┌───────────────────────────────────────────┐
-- │ mini.cursorword                           │
-- └───────────────────────────────────────────┘

Lib.later(function() require('mini.cursorword').setup() end)

-- ┌───────────────────────────────────────────┐
-- │ mini.bufremove                            │
-- └───────────────────────────────────────────┘

Lib.later(function() require('mini.bufremove').setup() end)

vim.api.nvim_create_user_command(
  'NeocraftBufferDelete',
  function(opts) require('mini.bufremove').delete(0, opts.bang) end,
  {
    bang = true,
    desc = 'Delete current buffer with MiniBufremove',
  }
)

vim.api.nvim_create_user_command(
  'NeocraftBufferWipeout',
  function(opts) require('mini.bufremove').wipeout(0, opts.bang) end,
  {
    bang = true,
    desc = 'Wipe out current buffer with MiniBufremove',
  }
)

return {}
