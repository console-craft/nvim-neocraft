local map = vim.keymap.set

-- ┌───────────────────────────────────────────┐
-- │ Helpers                                   │
-- └───────────────────────────────────────────┘

local function nmap(lhs, rhs, desc, opts)
  map('n', lhs, rhs, vim.tbl_extend('force', { silent = true, desc = desc }, opts or {}))
end
local function imap(lhs, rhs, desc, opts)
  map('i', lhs, rhs, vim.tbl_extend('force', { silent = true, desc = desc }, opts or {}))
end
local function xmap(lhs, rhs, desc, opts)
  map('x', lhs, rhs, vim.tbl_extend('force', { silent = true, desc = desc }, opts or {}))
end
local function cmap(lhs, rhs, desc, opts)
  map('c', lhs, rhs, vim.tbl_extend('force', { silent = true, desc = desc }, opts or {}))
end
local function tmap(lhs, rhs, desc, opts)
  map('t', lhs, rhs, vim.tbl_extend('force', { silent = true, desc = desc }, opts or {}))
end
local function nmap_leader(lhs, rhs, desc, opts) nmap('<leader>' .. lhs, rhs, desc, opts) end

local leader_group_clues = {
  { mode = 'n', keys = '<Leader>b', desc = '+Buffer' },
  { mode = 'n', keys = '<Leader>g', desc = '+Git' },
  { mode = 'n', keys = '<Leader>gR', desc = '+Remove' },
  { mode = 'n', keys = '<Leader>gb', desc = '+Bisect' },
  { mode = 'n', keys = '<Leader>gp', desc = '+Cherry-pick' },
  { mode = 'n', keys = '<Leader>gr', desc = '+Rebase' },
  { mode = 'n', keys = '<Leader>gw', desc = '+Worktrees' },
  { mode = 'n', keys = '<Leader>l', desc = '+List' },
  { mode = 'n', keys = '<Leader>x', desc = '+Focus' },
  { mode = 'n', keys = '<Leader><Tab>', desc = '+Tab' },
}

local function navigate(direction, cli_direction)
  local cur_win = vim.api.nvim_get_current_win()
  vim.api.nvim_cmd({ cmd = 'wincmd', args = { direction } }, {})
  local new_win = vim.api.nvim_get_current_win()

  -- If window didn't change, we're at the edge.
  if new_win == cur_win then
    -- Only try wezterm when actually running inside it.
    if vim.env.WEZTERM_PANE then
      -- Use wezterm cli to activate neighboring pane.
      vim.system({
        'wezterm',
        'cli',
        'activate-pane-direction',
        cli_direction,
      }, { detach = true })
    end
  end
end

local function goto_diagnostic(next, severity)
  local count = next and 1 or -1
  local level = severity and vim.diagnostic.severity[severity] or nil

  return function() vim.diagnostic.jump({ count = count, severity = level }) end
end

-- Toggles

local function show_toggle_state(text) vim.api.nvim_echo({ { text, 'Normal' } }, false, {}) end

local function get_toggle_text(name, enabled) return (enabled and 'Enabled: ' or 'Disabled: ') .. name end

local function toggle_window_option(name)
  local enabled = vim.api.nvim_get_option_value(name, { scope = 'local', win = 0 }) == true
  local toggled = not enabled

  vim.api.nvim_set_option_value(name, toggled, { scope = 'local', win = 0 })
  show_toggle_state(get_toggle_text(name, toggled))
end

local function toggle_global_option(name)
  vim.o[name] = not vim.o[name]
  show_toggle_state(get_toggle_text(name, vim.o[name]))
end

local function toggle_background()
  vim.o.background = vim.o.background == 'dark' and 'light' or 'dark'
  show_toggle_state('Background: ' .. vim.o.background)
end

local function toggle_conceallevel()
  if vim.wo.conceallevel == 0 then
    vim.wo.conceallevel = 3
    vim.opt_local.concealcursor = 'n'
  else
    vim.wo.conceallevel = 0
    vim.opt_local.concealcursor = ''
  end
  show_toggle_state('Conceal Level: ' .. vim.wo.conceallevel)
end

local function toggle_diagnostics()
  local bufnr = vim.api.nvim_get_current_buf()
  local enabled = vim.diagnostic.is_enabled({ bufnr = bufnr })

  vim.diagnostic.enable(not enabled, { bufnr = bufnr })
  show_toggle_state(get_toggle_text('diagnostic', not enabled))
end

local function toggle_folds()
  local opening = vim.wo.foldlevel == 0

  vim.cmd('normal! ' .. (opening and 'zR' or 'zM'))
  show_toggle_state(opening and 'Folds: all opened' or 'Folds: all closed')
end

-- Hard reload the current buffer and restart any attached LSP clients.
local function reload_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local view = vim.fn.winsaveview()

  -- If this is a hard reload and buffer has unsaved changes, confirm first.
  if vim.bo[bufnr].modified then
    local choice = vim.fn.confirm(
      'Discard unsaved changes in this buffer?',
      '&Yes\n&No',
      2 -- default to "No"
    )
    if choice ~= 1 then
      vim.fn.winrestview(view)
      return false
    end
  end

  -- Stop LSP clients on this buffer, but leave Copilot alone (it doesn't like being hard-stopped).
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    local name = (c.name or ''):lower()
    if name ~= 'copilot' and name ~= 'copilot_ls' then
      c:stop(true) -- force stop; they'll reattach on BufRead/FileType via your setup
    end
  end

  -- Re-read the file (hard = discard changes).
  vim.cmd.edit({ bang = true })

  vim.fn.winrestview(view)

  vim.api.nvim_echo({ { 'Reloaded buffer "' .. vim.api.nvim_buf_get_name(bufnr) .. '"', 'Normal' } }, false, {})

  return true
end

local function set_buffer_filetype()
  vim.ui.input({
    prompt = 'Set filetype (e.g. jsonc, lua, markdown): ',
    default = vim.bo.filetype,
  }, function(ft)
    if not ft or ft == '' then return end
    vim.bo.filetype = ft
    vim.api.nvim_echo({ { 'Buffer filetype set to "' .. ft .. '"', 'Normal' } }, false, {})
  end)
end

local function yank_relative_path()
  vim.fn.setreg('+', vim.fn.expand('%'))
  vim.api.nvim_echo({ { 'Yanked relative path to clipboard', 'Normal' } }, false, {})
end

local function yank_absolute_path()
  vim.fn.setreg('+', vim.fn.expand('%:p'))
  vim.api.nvim_echo({ { 'Yanked absolute path to clipboard', 'Normal' } }, false, {})
end

local function delete_other_buffers()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and b ~= vim.api.nvim_get_current_buf() then require('mini.bufremove').delete(b, false) end
  end
end

-- ┌───────────────────────────────────────────┐
-- │ Global Key Mappings                       │
-- └───────────────────────────────────────────┘

nmap('j', "v:count == 0 ? 'gj' : 'j'", 'Move cursor down one visual line', { expr = true })
nmap('k', "v:count == 0 ? 'gk' : 'k'", 'Move cursor up one visual line', { expr = true })
nmap(
  '<C-d>',
  function() return require('neocraft.actions').halfpage_down() end,
  'Scroll half-page down',
  { expr = true }
)
nmap('<C-u>', function() return require('neocraft.actions').halfpage_up() end, 'Scroll half-page up', { expr = true })
xmap('j', "v:count == 0 ? 'gj' : 'j'", 'Move cursor down one visual line', { expr = true })
xmap('k', "v:count == 0 ? 'gk' : 'k'", 'Move cursor up one visual line', { expr = true })
xmap('<', '<gv', 'Indent left and keep selection')
xmap('>', '>gv', 'Indent right and keep selection')

cmap('<M-h>', '<Left>', 'Left', { silent = false })
cmap('<M-l>', '<Right>', 'Right', { silent = false })
imap('<M-h>', '<Left>', 'Left', { noremap = false })
imap('<M-j>', '<Down>', 'Down', { noremap = false })
imap('<M-k>', '<Up>', 'Up', { noremap = false })
imap('<M-l>', '<Right>', 'Right', { noremap = false })
imap(',', ',<C-g>u', 'Insert comma with undo breakpoint')
imap('.', '.<C-g>u', 'Insert period with undo breakpoint')
imap(';', ';<C-g>u', 'Insert semicolon with undo breakpoint')
tmap('<M-h>', '<Left>', 'Left')
tmap('<M-j>', '<Down>', 'Down')
tmap('<M-k>', '<Up>', 'Up')
tmap('<M-l>', '<Right>', 'Right')
nmap('<M-h>', 'zh', 'Scroll view left')
nmap('<M-l>', 'zl', 'Scroll view right')
nmap('<M-H>', 'zH', 'Scroll view half-screen left')
nmap('<M-L>', 'zL', 'Scroll view half-screen right')
nmap('<M-j>', function() require('neocraft.actions').move_lines_down() end, 'Move line down')
nmap('<M-k>', function() require('neocraft.actions').move_lines_up() end, 'Move line up')
xmap('<M-j>', ":<C-u>execute \"'<,'>move '>+\" . v:count1<CR>gv=gv", 'Move selection down')
xmap('<M-k>', ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<CR>gv=gv", 'Move selection up')

nmap('<C-]>', '<Cmd>bnext<CR>', 'Next buffer')
nmap('<C-[>', '<Cmd>bprevious<CR>', 'Previous buffer')
nmap('<C-n>', '<cmd>enew | startinsert<cr>', 'New buffer')
nmap('<C-c>', function() require('mini.bufremove').delete(0, false) end, 'Delete buffer')
nmap('<C-p>', function() require('neocraft.pickers').actions() end, 'Action picker')
nmap('<C-/>', function() require('neocraft.terminal').toggle() end, 'Toggle floating terminal')
nmap('<C-_>', function() require('neocraft.terminal').toggle() end, 'Toggle floating terminal')
nmap('<C-x>', function() require('neocraft.plugins.mini').open_files() end, 'Toggle file explorer')
nmap('<C-Space>', function() require('neocraft.plugins.git').toggle_overlay() end, 'Toggle diff overlay')
nmap('[h', function() require('neocraft.plugins.git').goto_hunk('prev') end, 'Prev Git hunk')
nmap(']h', function() require('neocraft.plugins.git').goto_hunk('next') end, 'Next Git hunk')
nmap('[H', function() require('neocraft.plugins.git').goto_hunk('first') end, 'First Git hunk')
nmap(']H', function() require('neocraft.plugins.git').goto_hunk('last') end, 'Last Git hunk')
nmap('[g', function() require('neocraft.plugins.git').prev_pending_file(false) end, 'Prev unstaged Git file')
nmap(']g', function() require('neocraft.plugins.git').next_pending_file(false) end, 'Next unstaged Git file')
nmap('[G', function() require('neocraft.plugins.git').prev_pending_file(true) end, 'Prev staged Git file')
nmap(']G', function() require('neocraft.plugins.git').next_pending_file(true) end, 'Next staged Git file')

nmap('[<Tab>', '<Cmd>tabprevious<CR>', 'Previous tab')
nmap(']<Tab>', '<Cmd>tabnext<CR>', 'Next tab')

-- TODO: (in the future) - format (\f), minimap (\m)
nmap('\\b', toggle_background, 'Toggle background')
nmap('\\c', function() toggle_window_option('cursorline') end, 'Toggle cursorline')
nmap('\\`', toggle_conceallevel, 'Toggle conceallevel')
nmap('\\d', toggle_diagnostics, 'Toggle diagnostics')
nmap('\\h', function() require('neocraft.plugins.lsp').toggle_inlay_hints() end, 'Toggle inlay hints')
nmap('\\i', function() toggle_global_option('ignorecase') end, 'Toggle ignorecase')
nmap('\\l', function() require('neocraft.plugins.lsp').toggle_codelens() end, 'Toggle code lens')
nmap('\\n', function() toggle_window_option('number') end, 'Toggle line numbers')
nmap('\\r', function() toggle_window_option('relativenumber') end, 'Toggle relative numbers')
nmap('\\s', function() toggle_window_option('spell') end, 'Toggle spell checking')
nmap('\\w', function() toggle_window_option('wrap') end, 'Toggle line wrap')
nmap('\\z', toggle_folds, 'Toggle folds open or closed')

-- Hot-path leader mappings
nmap('<C-CR>', function() require('neocraft.actions').toggle_maximized() end, 'Maximize')
nmap_leader('f', function() require('neocraft.plugins.mini').pick_files() end, 'Find files')
nmap_leader('/', function() require('neocraft.plugins.mini').grep_live() end, 'Grep text')
nmap_leader('*', function() require('neocraft.plugins.mini').grep_cword() end, 'Grep word')
nmap_leader('r', function() require('neocraft.plugins.mini').resume_picker() end, 'Resume picker')
nmap_leader('p', function() require('neocraft.plugins.mini').pick_registry() end, 'Pickers')
nmap_leader('y', [[:silent keepjumps %yank<CR>]], 'Copy content')
nmap_leader('z', 'zA', 'Toggle current fold')
nmap_leader('s', '<C-w>s', 'Split below')
nmap_leader('v', '<C-w>v', 'Split right')
nmap_leader('q', '<C-w>c', 'Close window')

-- Buffer namespace
nmap_leader('ba', '<cmd>e #<cr>', 'Alternate buffer')
nmap_leader('bd', delete_other_buffers, 'Delete other')
nmap_leader('br', reload_buffer, 'Reload buffer')
nmap_leader('bt', set_buffer_filetype, 'Set buffer type')
nmap_leader('by', yank_relative_path, 'Copy relative path')
nmap_leader('bY', yank_absolute_path, 'Copy absolute path')

-- Tabs namespace
nmap_leader('<Tab><Tab>', 'g<Tab>', 'Alternate tab')
nmap_leader('<Tab>n', '<Cmd>tabnew<CR>', 'New tab')
nmap_leader('<Tab>d', '<Cmd>tabonly<CR>', 'Delete other tabs')
nmap_leader('<Tab>q', '<Cmd>tabclose<CR>', 'Close tab')

-- Git namespaces
nmap('go', function() require('neocraft.plugins.git').open() end, 'Git open')
xmap('go', function() require('neocraft.plugins.git').open() end, 'Git open')
nmap_leader('ga', function() require('neocraft.plugins.git').add_file() end, 'Add buffer')
nmap_leader('gA', function() require('neocraft.plugins.git').add_all() end, 'Add all')
nmap_leader('gB', function() require('neocraft.plugins.git').blame() end, 'Blame')
nmap_leader('gbS', function() require('neocraft.plugins.git').bisect_start() end, 'Start bisect')
nmap_leader('gbg', function() require('neocraft.plugins.git').bisect_good() end, 'Mark current commit good')
nmap_leader('gbb', function() require('neocraft.plugins.git').bisect_bad() end, 'Mark current commit bad')
nmap_leader('gbs', function() require('neocraft.plugins.git').bisect_skip() end, 'Skip current commit')
nmap_leader('gbr', function() require('neocraft.plugins.git').bisect_reset() end, 'Reset bisect')
nmap_leader('gbl', function() require('neocraft.plugins.git').bisect_log() end, 'Log bisect')
nmap_leader('gbv', function() require('neocraft.plugins.git').bisect_visualize() end, 'Visualize bisect')
nmap_leader('gc', function() require('neocraft.plugins.git').commit() end, 'Commit')
nmap_leader('gC', function() require('neocraft.plugins.git').commit_amend() end, 'Commit amend')
nmap_leader('gd', function() require('neocraft.plugins.git').diff() end, 'Diff')
nmap_leader('gD', function() require('neocraft.plugins.git').diff_staged() end, 'Diff staged')
nmap_leader('gl', function() require('neocraft.plugins.git').log_repo() end, 'Log')
nmap_leader('gL', function() require('neocraft.plugins.git').log_buffer() end, 'Log buffer')
nmap_leader('gRb', function() require('neocraft.plugins.git').delete_local_branch_prompt() end, 'Delete local branch')
nmap_leader('gRB', function() require('neocraft.plugins.git').delete_remote_branch_prompt() end, 'Delete remote branch')
nmap_leader(
  'gRc',
  function() require('neocraft.plugins.git').reset_latest_commit_mixed() end,
  'Remove latest commit (keep changes)'
)
nmap_leader(
  'gRC',
  function() require('neocraft.plugins.git').reset_latest_commit_hard() end,
  'Remove latest commit (discard changes)'
)
nmap_leader('gRp', function() require('neocraft.plugins.git').prune_branches() end, 'Prune stale branches')
nmap_leader(
  'gRr',
  function() require('neocraft.plugins.git').reset_and_clean() end,
  'Reset changes and clean untracked'
)
nmap_leader('gwa', function() require('neocraft.worktrees').add_prompt() end, 'Add worktree')
nmap_leader('gwc', function() require('neocraft.worktrees').copy_files_prompt() end, 'Copy files to worktree')
nmap_leader('gwp', function() require('neocraft.worktrees').prune() end, 'Prune worktrees')
nmap_leader('gwr', function() require('neocraft.worktrees').remove_prompt() end, 'Remove worktree')
nmap_leader('gwy', function() require('neocraft.worktrees').yank_path_prompt() end, 'Yank worktree path')
nmap_leader('gpa', function() require('neocraft.plugins.git').cherry_pick_abort() end, 'Abort cherry-pick')
nmap_leader('gpc', function() require('neocraft.plugins.git').cherry_pick_continue() end, 'Continue cherry-pick')
nmap_leader('gpp', function() require('neocraft.plugins.git').cherry_pick() end, 'Pick commits')
nmap_leader('gps', function() require('neocraft.plugins.git').cherry_pick_skip() end, 'Skip cherry-pick step')
nmap_leader('gra', function() require('neocraft.plugins.git').rebase_abort() end, 'Abort rebase')
nmap_leader('grc', function() require('neocraft.plugins.git').rebase_continue() end, 'Continue rebase')
nmap_leader('grr', function() require('neocraft.plugins.git').rebase_interactive() end, 'Rebase interactive')
nmap_leader('grs', function() require('neocraft.plugins.git').rebase_skip() end, 'Skip rebase step')
nmap_leader('gs', function() require('neocraft.plugins.git').status() end, 'Status')

-- Lists namespace
nmap_leader('lc', function()
  local success, err = pcall(vim.cmd.copen)
  if not success and err then vim.notify(err, vim.log.levels.ERROR) end
end, 'Quickfix')
nmap_leader('ln', function() require('mini.notify').show_history() end, 'Notifications')
nmap_leader('ll', function()
  vim.diagnostic.setloclist()
  local success, err = pcall(vim.cmd.lopen)
  if not success and err then vim.notify(err, vim.log.levels.ERROR) end
end, 'Location')
nmap_leader('lp', function() require('neocraft.core.pack').show_pack() end, 'Plugins')

-- Focus namespace
nmap_leader('<Leader>', function() require('neocraft.visits').pick_focus() end, 'Focus list')
nmap_leader('xa', function() require('neocraft.visits').add_focus() end, 'Add item to focus list')
nmap_leader('xc', function() require('neocraft.visits').remove_focus() end, 'Clear item from focus list')
nmap_leader('xd', function()
  local choice = vim.fn.confirm('Delete all from focus list?', '&Yes\n&No\n&Cancel', 2)
  if choice == 1 then require('neocraft.visits').remove_all_focus() end
end, 'Delete all from focus list')

nmap('[p', '<Cmd>exe "iput! " . v:register<CR>', 'Paste Above')
nmap(']p', '<Cmd>exe "iput "  . v:register<CR>', 'Paste Below')
nmap('gV', '`[v`]', 'Reselect last paste/change')
xmap('p', 'P', 'Paste without yanking replaced selection')

nmap('gd', '<C-]>', 'Goto definition or tag')

nmap('<C-s>', '<Cmd>silent! update | redraw<CR>', 'Save')
imap('<C-s>', '<Esc><Cmd>silent! update | redraw<CR>', 'Save and go to Normal mode')
xmap('<C-s>', '<Esc><Cmd>silent! update | redraw<CR>', 'Save and go to Normal mode')
map(
  { 'i', 'x', 'n', 's' },
  '<C-S-r>',
  function() require('neocraft.actions').restart_neovim() end,
  { desc = 'Restart Neovim' }
)
nmap('<C-q>', function() require('neocraft.actions').quit_neovim() end, 'Quit Neovim')

nmap('<Esc>', function() require('neocraft.actions').clear_on_escape() end, 'Run multiple clearing actions')

nmap('<C-h>', function() navigate('h', 'Left') end, 'Focus window to the left')
tmap('<C-h>', function() navigate('h', 'Left') end, 'Focus window to the left')
nmap('<C-j>', function() navigate('j', 'Down') end, 'Focus window below')
tmap('<C-j>', function() navigate('j', 'Down') end, 'Focus window below')
nmap('<C-k>', function() navigate('k', 'Up') end, 'Focus window to the right')
tmap('<C-k>', function() navigate('k', 'Up') end, 'Focus window to the right')
nmap('<C-l>', function() navigate('l', 'Right') end, 'Focus window above')
tmap('<C-l>', function() navigate('l', 'Right') end, 'Focus window above')

nmap(
  '<C-Left>',
  '"<Cmd>vertical resize -" . v:count1 . "<CR>"',
  'Decrease window width',
  { expr = true, replace_keycodes = false }
)
nmap(
  '<C-Down>',
  '"<Cmd>resize -"          . v:count1 . "<CR>"',
  'Decrease window height',
  { expr = true, replace_keycodes = false }
)
nmap(
  '<C-Up>',
  '"<Cmd>resize +"          . v:count1 . "<CR>"',
  'Increase window height',
  { expr = true, replace_keycodes = false }
)
nmap(
  '<C-Right>',
  '"<Cmd>vertical resize +" . v:count1 . "<CR>"',
  'Increase window width',
  { expr = true, replace_keycodes = false }
)

nmap(']e', goto_diagnostic(true, 'ERROR'), 'Next diagnostic error')
nmap('[e', goto_diagnostic(false, 'ERROR'), 'Prev diagnostic error')

nmap(']w', goto_diagnostic(true, 'WARN'), 'Next diagnostic warning')
nmap('[w', goto_diagnostic(false, 'WARN'), 'Prev diagnostic warning')

tmap('<Esc><Esc>', '<C-\\><C-n>', 'Exit terminal mode')
tmap('<C-/>', function() require('neocraft.terminal').toggle() end, 'Toggle floating terminal')
tmap('<C-_>', function() require('neocraft.terminal').toggle() end, 'Toggle floating terminal')

return {
  leader_group_clues = leader_group_clues,
}
