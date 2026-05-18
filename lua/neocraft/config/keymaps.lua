-- Key mappings for Neocraft.

-- stylua: ignore start

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local editing = require('neocraft.features.editing')
local editor = require('neocraft.features.editor')
local workspace = require('neocraft.features.workspace')
local terminal = require('neocraft.features.terminal')
local pickers = require('neocraft.features.pickers')
local completions = require('neocraft.features.completions')
local git = require('neocraft.features.git')
local plugins = require('neocraft.core.pack')
local lsp = require('neocraft.features.lsp')
local formatting = require('neocraft.features.formatting')
local treesitter = require('neocraft.features.treesitter')
local focus = require('neocraft.features.focus')
local mini = require('neocraft.features.mini')

local map = vim.keymap.set

local function nmap(lhs, rhs, desc, opts) map('n', lhs, rhs, vim.tbl_extend('force', { silent = true, desc = desc }, opts or {})) end
local function imap(lhs, rhs, desc, opts) map('i', lhs, rhs, vim.tbl_extend('force', { silent = true, desc = desc }, opts or {})) end
local function xmap(lhs, rhs, desc, opts) map('x', lhs, rhs, vim.tbl_extend('force', { silent = true, desc = desc }, opts or {})) end
local function cmap(lhs, rhs, desc, opts) map('c', lhs, rhs, vim.tbl_extend('force', { silent = true, desc = desc }, opts or {})) end
local function tmap(lhs, rhs, desc, opts) map('t', lhs, rhs, vim.tbl_extend('force', { silent = true, desc = desc }, opts or {})) end

local function nmap_leader(lhs, rhs, desc, opts) nmap('<leader>' .. lhs, rhs, desc, opts) end

local leader_group_clues = {
  { mode = 'n',   keys = '<Leader>b',   desc = '+Buffer' },
  { mode = 'n',   keys = '<Leader>c',   desc = '+Code' },
  { mode = 'n',   keys = '<Leader>cc',  desc = '+Copilot' },
  { mode = 'n',   keys = '<Leader>cl',  desc = '+Logs' },
  { mode = 'n',   keys = '<Leader>g',   desc = '+Git' },
  { mode = 'n',   keys = '<Leader>gR',  desc = '+Remove' },
  { mode = 'n',   keys = '<Leader>gb',  desc = '+Bisect' },
  { mode = 'n',   keys = '<Leader>gp',  desc = '+Cherry-pick' },
  { mode = 'n',   keys = '<Leader>gr',  desc = '+Rebase' },
  { mode = 'n',   keys = '<Leader>gw',  desc = '+Worktrees' },
  { mode = 'n',   keys = '<Leader>l',   desc = '+List' },
  { mode = 'n',   keys = '<Leader>x',   desc = '+Focus' },
}

-- ┌───────────────────────────────────────────┐
-- │ Editing mappings                          │
-- └───────────────────────────────────────────┘

-- Cursor and line movement

nmap( 'j',      function() return editing.move_by_visual_line_down() end,   'Move cursor down one visual line', { expr = true })
nmap( 'k',      function() return editing.move_by_visual_line_up() end,     'Move cursor up one visual line',   { expr = true })
xmap( 'j',      function() return editing.move_by_visual_line_down() end,   'Move cursor down one visual line', { expr = true })
xmap( 'k',      function() return editing.move_by_visual_line_up() end,     'Move cursor up one visual line',   { expr = true })
imap( '<M-h>',  function() return editing.move_cursor_left() end,        'Move cursor left',                 { expr = true })
imap( '<M-j>',  function() return editing.move_cursor_down() end,        'Move cursor down',                 { expr = true })
imap( '<M-k>',  function() return editing.move_cursor_up() end,          'Move cursor up',                   { expr = true })
imap( '<M-l>',  function() return editing.move_cursor_right() end,       'Move cursor right',                { expr = true })
tmap( '<M-h>',  function() return editing.move_cursor_left() end,        'Move cursor left',                 { expr = true })
tmap( '<M-j>',  function() return editing.move_cursor_down() end,        'Move cursor down',                 { expr = true })
tmap( '<M-k>',  function() return editing.move_cursor_up() end,          'Move cursor up',                   { expr = true })
tmap( '<M-l>',  function() return editing.move_cursor_right() end,       'Move cursor right',                { expr = true })
cmap( '<M-h>',  function() return editing.move_cursor_left() end,        'Move cursor left',                 { expr = true, silent = false })
cmap( '<M-j>',  function() return editing.move_cursor_down() end,        'Move cursor down',                 { expr = true, silent = false })
cmap( '<M-k>',  function() return editing.move_cursor_up() end,          'Move cursor up',                   { expr = true, silent = false })
cmap( '<M-l>',  function() return editing.move_cursor_right() end,       'Move cursor right',                { expr = true, silent = false })
nmap( '<M-j>',  function() editing.move_lines_down() end,                'Move line down')
nmap( '<M-k>',  function() editing.move_lines_up() end,                  'Move line up')
xmap( '<M-j>',  function() editing.move_selection_down() end,            'Move selection down')
xmap( '<M-k>',  function() editing.move_selection_up() end,              'Move selection up')

-- Undo

imap( ',',  function() return editing.comma_with_undo_breakpoint() end,      'Insert comma with undo breakpoint',      { expr = true })
imap( '.',  function() return editing.period_with_undo_breakpoint() end,     'Insert period with undo breakpoint',     { expr = true })
imap( ';',  function() return editing.semicolon_with_undo_breakpoint() end,  'Insert semicolon with undo breakpoint',  { expr = true })

-- Selections

xmap( '<C-Space>',  function() treesitter.select_parent_node() end,                'Increase selection')
xmap( '<BS>',       function() treesitter.select_child_node() end,                 'Decrease selection')
xmap( '<',          function() return editing.indent_left_keep_selection() end,    'Indent left and keep selection',   { expr = true })
xmap( '>',          function() return editing.indent_right_keep_selection() end,   'Indent right and keep selection',  { expr = true })

-- Pasting

xmap( 'p',    function() return editing.paste_without_yanking_selection() end,   'Paste without yanking replaced selection',   { expr = true })
nmap( '[p',   function() editing.paste_above() end,                              'Paste Above')
nmap( ']p',   function() editing.paste_below() end,                              'Paste Below')
nmap( 'gV',   function() return editing.reselect_last_paste_or_change() end,     'Reselect last paste/change',                 { expr = true })

-- Searching

nmap( 'n',  function() editing.search_motion_with_minimap_refresh('n') end,  'Next search match')
nmap( 'N',  function() editing.search_motion_with_minimap_refresh('N') end,  'Prev search match')
nmap( '*',  function() editing.search_motion_with_minimap_refresh('*') end,  'Search word forward')
nmap( '#',  function() editing.search_motion_with_minimap_refresh('#') end,  'Search word backward')

-- Scrolling

nmap( '<C-d>',  function() return editing.halfpage_down() end,   'Scroll half-page down',          { expr = true })
nmap( '<C-u>',  function() return editing.halfpage_up() end,     'Scroll half-page up',            { expr = true })
map({ 'n', 'i', 'x', 's' }, '<ScrollWheelUp>',    function() return editing.mouse_scroll_without_animation('<ScrollWheelUp>') end,    { expr = true, silent = true, desc = 'Mouse scroll up' })
map({ 'n', 'i', 'x', 's' }, '<ScrollWheelDown>',  function() return editing.mouse_scroll_without_animation('<ScrollWheelDown>') end,  { expr = true, silent = true, desc = 'Mouse scroll down' })
map({ 'n', 'i', 'x', 's' }, '<ScrollWheelLeft>',  function() return editing.mouse_scroll_without_animation('<ScrollWheelLeft>') end,  { expr = true, silent = true, desc = 'Mouse scroll left' })
map({ 'n', 'i', 'x', 's' }, '<ScrollWheelRight>', function() return editing.mouse_scroll_without_animation('<ScrollWheelRight>') end, { expr = true, silent = true, desc = 'Mouse scroll right' })
nmap( '<M-h>',  function() editing.scroll_view_left() end,       'Scroll view left')
nmap( '<M-l>',  function() editing.scroll_view_right() end,      'Scroll view right')
nmap( '<M-H>',  function() editing.scroll_view_half_left() end,  'Scroll view half-screen left')
nmap( '<M-L>',  function() editing.scroll_view_half_right() end, 'Scroll view half-screen right')

-- Diagnostics

nmap( ']e',   function() editing.goto_diagnostic(true, 'ERROR') end,   'Next diagnostic error')
nmap( '[e',   function() editing.goto_diagnostic(false, 'ERROR') end,  'Prev diagnostic error')
nmap( ']w',   function() editing.goto_diagnostic(true, 'WARN') end,    'Next diagnostic warning')
nmap( '[w',   function() editing.goto_diagnostic(false, 'WARN') end,   'Prev diagnostic warning')

-- ┌───────────────────────────────────────────┐
-- │ Leader hot-paths (single key) mappings    │
-- └───────────────────────────────────────────┘

nmap_leader(  'd',          function() editing.line_diagnostics() end,            'Line diagnostics')
nmap_leader(  'e',          function() mini.explore_files() end,                 'Explore files')
nmap_leader(  'f',          function() pickers.files() end,                      'Find files')
nmap_leader(  'F',          function() pickers.all_files() end,                  'Find all files')
nmap_leader(  'p',          function() pickers.registry() end,                   'Pickers')
nmap_leader(  'q',          function() workspace.close_window_or_tab() end,      'Close window or tab')
nmap_leader(  'r',          function() pickers.resume() end,                     'Resume picker')
nmap_leader(  's',          function() workspace.split_below() end,              'Split below')
nmap_leader(  'u',          function() plugins.update() end,                            'Update plugins')
nmap_leader(  'v',          function() workspace.split_right() end,              'Split right')
nmap_leader(  'z',          function() return editor.toggle_current_fold() end,  'Toggle current fold',  { expr = true })
nmap_leader(  'y',          function() workspace.copy_buffer_content() end,      'Copy content')
nmap_leader(  '<Leader>',   function() focus.pick_focus() end,                   'Focus list')
nmap_leader(  '<Tab>',      function() workspace.new_tab() end,                  'New tab')
nmap_leader(  '*',          function() pickers.grep_cword() end,                 'Grep word')
nmap_leader(  '#',          function() pickers.all_grep_cword() end,             'Grep all word')
nmap_leader(  '/',          function() pickers.grep_live() end,                  'Grep text')
nmap_leader(  '?',          function() pickers.all_grep_live() end,              'Grep all text')

-- ┌───────────────────────────────────────────┐
-- │ Toggle mappings                           │
-- └───────────────────────────────────────────┘

nmap(   '\\b', function() editor.toggle_background() end,                      'Toggle background')
nmap(   '\\c', function() editor.toggle_window_option('cursorline') end,       'Toggle cursorline')
nmap(   '\\d', function() editor.toggle_diagnostics() end,                     'Toggle diagnostics')
nmap(   '\\f', function() editor.toggle_format_on_save() end,                  'Toggle format on save')
nmap(   '\\h', function() lsp.toggle_inlay_hints() end,                        'Toggle inlay hints')
nmap(   '\\i', function() editor.toggle_global_option('ignorecase') end,       'Toggle ignorecase')
nmap(   '\\l', function() lsp.toggle_codelens() end,                           'Toggle code lens')
nmap(   '\\m', function() mini.toggle_map() end,                               'Toggle minimap')
nmap(   '\\n', function() editor.toggle_window_option('number') end,           'Toggle line numbers')
nmap(   '\\r', function() editor.toggle_window_option('relativenumber') end,   'Toggle relative numbers')
nmap(   '\\s', function() editor.toggle_window_option('spell') end,            'Toggle spell checking')
nmap(   '\\w', function() editor.toggle_window_option('wrap') end,             'Toggle line wrap')
nmap(   '\\z', function() editor.toggle_folds() end,                           'Toggle folds open or closed')
nmap(   '\\`', function() editor.toggle_conceallevel() end,                    'Toggle conceallevel')

-- ┌───────────────────────────────────────────┐
-- │ Buffer mappings                           │
-- └───────────────────────────────────────────┘

nmap_leader(  'ba',     function() workspace.alternate_buffer() end,       'Alternate buffer')
nmap_leader(  'bc',     function() workspace.delete_other_buffers() end,   'Close other buffers')
nmap_leader(  'br',     function() workspace.reload_buffer() end,          'Reload buffer')
nmap_leader(  'bt',     function() workspace.set_buffer_filetype() end,    'Set buffer type')
nmap_leader(  'by',     function() workspace.yank_relative_path() end,     'Copy relative path')
nmap_leader(  'bY',     function() workspace.yank_absolute_path() end,     'Copy absolute path')
nmap(         '<C-n>',  function() workspace.new_buffer() end,             'New buffer')
nmap(         '<C-]>',  function() workspace.next_buffer() end,            'Next buffer')
nmap(         '<C-[>',  function() workspace.previous_buffer() end,        'Previous buffer')
nmap(         '<C-c>',  function() workspace.delete_buffer() end,          'Delete buffer')
nmap(         '<C-s>',  function() workspace.save() end,                   'Save')
imap(         '<C-s>',  function() workspace.save_and_normal_mode() end,   'Save and go to Normal mode')
xmap(         '<C-s>',  function() workspace.save_and_normal_mode() end,   'Save and go to Normal mode')
map( { 'i', 'x', 'n', 's' }, '<C-S-s>', function() workspace.save_without_formatting() end, { silent = true, desc = 'Save without formatting' })

-- ┌───────────────────────────────────────────┐
-- │ Window mappings                           │
-- └───────────────────────────────────────────┘

nmap( '<C-h>',      function() workspace.focus_left() end,         'Focus window to the left')
nmap( '<C-j>',      function() workspace.focus_down() end,         'Focus window below')
nmap( '<C-k>',      function() workspace.focus_up() end,           'Focus window above')
nmap( '<C-l>',      function() workspace.focus_right() end,        'Focus window to the right')
nmap( '<C-Left>',   function() workspace.resize_left() end,        'Decrease window width')
nmap( '<C-Down>',   function() workspace.resize_down() end,        'Decrease window height')
nmap( '<C-Up>',     function() workspace.resize_up() end,          'Increase window height')
nmap( '<C-Right>',  function() workspace.resize_right() end,       'Increase window width')
nmap( '<C-CR>',     function() workspace.toggle_maximized() end,   'Maximize')

-- ┌───────────────────────────────────────────┐
-- │ Terminal mappings                         │
-- └───────────────────────────────────────────┘

tmap( '<Esc><Esc>',   function() return terminal.exit_terminal_mode() end,  'Exit terminal mode',         { expr = true })
nmap( '<C-/>',        function() terminal.toggle() end,                     'Toggle floating terminal')
nmap( '<C-_>',        function() terminal.toggle() end,                     'Toggle floating terminal')
tmap( '<C-/>',        function() terminal.toggle() end,                     'Toggle floating terminal')
tmap( '<C-_>',        function() terminal.toggle() end,                     'Toggle floating terminal')

-- ┌───────────────────────────────────────────┐
-- │ Tab mappings                              │
-- └───────────────────────────────────────────┘

nmap(']<Tab>', function() workspace.next_tab() end, 'Next tab')
nmap('[<Tab>', function() workspace.previous_tab() end, 'Previous tab')

-- ┌───────────────────────────────────────────┐
-- │ Completion mappings                       │
-- └───────────────────────────────────────────┘

imap('<C-Space>', function() completions.trigger_manual_completion() end, 'Manually trigger completions')
imap('<C-e>', function() return completions.close_completion_or_accept_inline_completion_to_eol() end, 'Close completions / Accept to EOL', { expr = true })
imap('<C-]>', function() return completions.dismiss_inline_completion_or_ctrl_right_square() end, 'Dismiss active inline completion', { expr = true })
imap('<CR>', function() return completions.accept_completion_or_cr() end, 'Accept selected completion item or insert newline', { expr = true })
imap('<C-CR>', function() return completions.close_completion_and_cr() end, 'Close completion menu and insert newline', { expr = true })
map({ 'i', 's' }, '<Tab>', function() return completions.accept_inline_completion_or_snippet_jump_next_or_tab() end, { expr = true, silent = true, desc = 'Jump to next snippet tabstop or insert tab', })
map({ 'i', 's' }, '<S-Tab>', function() return completions.snippet_jump_prev_or_stab() end, { expr = true, silent = true, desc = 'Jump to previous snippet tabstop', })
imap('<C-Tab>', function() return completions.insert_literal_tab() end, 'Insert literal tab', { expr = true })

-- ┌───────────────────────────────────────────┐
-- │ Code mappings                             │
-- └───────────────────────────────────────────┘

nmap('gd', function() return editing.go_to_definition_or_tag() end, 'Go to definition / tag', { expr = true })
nmap_leader('cd', function() lsp.definition_in_vsplit() end, 'Go to definition in vsplit')
nmap_leader('cf', function() formatting.format() end, 'Format buffer')
nmap_leader('cla', function() lsp.show_attached_clients() end, 'Attached LSP clients')
nmap_leader('clc', function() formatting.info() end, 'Conform info')
nmap_leader('cll', function() lsp.lsp_info() end, 'LSP info')

-- ┌───────────────────────────────────────────┐
-- │ Pickers                                   │
-- └───────────────────────────────────────────┘

nmap('<C-p>', function() pickers.actions() end, 'Action picker')

-- ┌───────────────────────────────────────────┐
-- │ List mappings                             │
-- └───────────────────────────────────────────┘

nmap_leader('lc', function() editor.open_quickfix_list() end, 'Quickfix')
nmap_leader('ln', function() editor.show_notifications() end, 'Notifications')
nmap_leader('ll', function() editor.open_location_list() end, 'Location')
nmap_leader('lp', function() vim.cmd.tabnew() plugins.show_pack() end, 'Plugins')
nmap_leader('lt', function() pickers.todos() end, 'TODOs')
nmap_leader('lT', function() pickers.all_todos() end, 'All TODOs')

-- ┌───────────────────────────────────────────┐
-- │ Focus list mappings                       │
-- └───────────────────────────────────────────┘

nmap_leader('xa', function() focus.add_focus() end, 'Add to focus list')
nmap_leader('xd', function() focus.remove_focus() end, 'Delete from focus list')
nmap_leader('xc', function() focus.clear_focus_list() end, 'Clear focus list')

-- ┌───────────────────────────────────────────┐
-- │ Git mappings                              │
-- └───────────────────────────────────────────┘

nmap_leader('ga',   function() git.add_file() end, 'Add file')
nmap_leader('gA',   function() git.add_all() end, 'Add all')
nmap_leader('gbS',  function() git.bisect_start() end, 'Start bisect')
nmap_leader('gbg', function() git.bisect_good() end, 'Mark current commit good')
nmap_leader('gbb', function() git.bisect_bad() end, 'Mark current commit bad')
nmap_leader('gbs', function() git.bisect_skip() end, 'Skip current commit')
nmap_leader('gbr', function() git.bisect_reset() end, 'Reset bisect')
nmap_leader('gbl', function() git.bisect_log() end, 'Log bisect')
nmap_leader('gbv', function() git.bisect_visualize() end, 'Visualize bisect')
nmap_leader('gc', function() git.commit() end, 'Commit')
nmap_leader('gC', function() git.commit_amend() end, 'Commit amend')
nmap_leader('gd', function() git.open_diff() end, 'Diff unstaged')
nmap_leader('gD', function() git.open_staged_diff() end, 'Diff staged')
nmap_leader('gW', function() git.open_working_tree_diff() end, 'Diff working tree')
nmap_leader('gh',   function() git.open_file_history() end, 'File history')
nmap_leader('gl', function() git.open_log() end, 'Log')
nmap_leader('gu', function() git.unstage_file() end, 'Unstage files')
nmap_leader('gU', function() git.unstage_all() end, 'Unstage all')
nmap_leader('gRb', function() git.delete_local_branch() end, 'Delete local branch')
nmap_leader('gRB', function() git.delete_remote_branch() end, 'Delete remote branch')
nmap_leader('gRc', function() git.reset_latest_commit_mixed() end, 'Remove latest commit (keep changes)')
nmap_leader('gRC', function() git.reset_latest_commit_hard() end, 'Remove latest commit (discard changes)')
nmap_leader('gRp', function() git.prune_branches() end, 'Prune stale branches')
nmap_leader('gRr', function() git.reset_and_clean() end, 'Reset changes and clean untracked')
nmap_leader('gwa', function() git.add_worktree() end, 'Add worktree')
nmap_leader('gwc', function() git.copy_files_to_worktree() end, 'Copy files to worktree')
nmap_leader('gwp', function() git.prune_worktrees() end, 'Prune worktrees')
nmap_leader('gwr', function() git.remove_worktree() end, 'Remove worktree')
nmap_leader('gwy', function() git.yank_worktree_path() end, 'Yank worktree path')
nmap_leader('gpa', function() git.cherry_pick_abort() end, 'Abort cherry-pick')
nmap_leader('gpc', function() git.cherry_pick_continue() end, 'Continue cherry-pick')
nmap_leader('gpp', function() git.cherry_pick() end, 'Pick commits')
nmap_leader('gps', function() git.cherry_pick_skip() end, 'Skip cherry-pick step')
nmap_leader('gra', function() git.rebase_abort() end, 'Abort rebase')
nmap_leader('grc', function() git.rebase_continue() end, 'Continue rebase')
nmap_leader('grr', function() git.rebase_interactive() end, 'Rebase interactive')
nmap_leader('grs', function() git.rebase_skip() end, 'Skip rebase step')
nmap_leader('gs', function() git.status() end, 'Status')
nmap('<C-Space>', function() git.toggle_overlay() end, 'Toggle diff overlay')
nmap('[h', function() git.goto_hunk('prev') end, 'Prev Git hunk')
nmap(']h', function() git.goto_hunk('next') end, 'Next Git hunk')
nmap('[H', function() git.goto_hunk('first') end, 'First Git hunk')
nmap(']H', function() git.goto_hunk('last') end, 'Last Git hunk')
nmap('[g', function() git.prev_pending_file(false) end, 'Prev unstaged Git file')
nmap(']g', function() git.next_pending_file(false) end, 'Next unstaged Git file')
nmap('[G', function() git.prev_pending_file(true) end, 'Prev staged Git file')
nmap(']G', function() git.next_pending_file(true) end, 'Next staged Git file')
nmap('go', function() git.open() end, 'Git open')
xmap('go', function() git.open() end, 'Git open')

-- ┌───────────────────────────────────────────┐
-- │ Dismiss UI mappings                       │
-- └───────────────────────────────────────────┘

nmap('<Esc>', function() editor.clear_on_escape() end, 'Run clearing actions')

-- ┌───────────────────────────────────────────┐
-- │ Session mappings                          │
-- └───────────────────────────────────────────┘

map( { 'i', 'x', 'n', 's' }, '<C-S-r>', function() editor.restart_neovim() end, { desc = 'Restart Neovim' })
nmap('<C-q>', function() editor.quit_neovim() end, 'Quit Neovim')

-- stylua: ignore start

return {
  leader_group_clues = leader_group_clues,
}
