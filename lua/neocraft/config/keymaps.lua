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
local function xmap_leader(lhs, rhs, desc, opts) xmap('<leader>' .. lhs, rhs, desc, opts) end

local leader_group_clues = {
  { mode = 'n', keys = '<Leader>b', desc = '+Buffers' },
  { mode = 'n', keys = '<Leader>g', desc = '+Git' },
  { mode = 'n', keys = '<Leader><Tab>', desc = '+Tabs' },
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
  local go = next and vim.diagnostic.goto_next or vim.diagnostic.goto_prev
  local level = severity and vim.diagnostic.severity[severity] or nil

  return function() go({ severity = level }) end
end

-- Toggles

local function show_toggle_state(text) vim.api.nvim_echo({ { text, 'Normal' } }, false, {}) end

local function get_toggle_text(name, enabled) return (enabled and 'Enabled: ' or 'Disabled: ') .. name end

local function toggle_window_option(name)
  vim.wo[name] = not vim.wo[name]
  show_toggle_state(get_toggle_text(name, vim.wo[name]))
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

local function toggle_hlsearch()
  vim.v.hlsearch = 1 - vim.v.hlsearch
  show_toggle_state(get_toggle_text('hlsearch', vim.v.hlsearch == 1))
end

local function toggle_diagnostics()
  local bufnr = vim.api.nvim_get_current_buf()
  local enabled = vim.diagnostic.is_enabled({ bufnr = bufnr })

  vim.diagnostic.enable(not enabled, { bufnr = bufnr })
  show_toggle_state(get_toggle_text('diagnostic', not enabled))
end

-- TODO: revisit at later stage
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
      c.stop(true) -- force stop; they'll reattach on BufRead/FileType via your setup
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
xmap('j', "v:count == 0 ? 'gj' : 'j'", 'Move cursor down one visual line', { expr = true })
xmap('k', "v:count == 0 ? 'gk' : 'k'", 'Move cursor up one visual line', { expr = true })

cmap('<M-h>', '<Left>', 'Left', { silent = false })
cmap('<M-l>', '<Right>', 'Right', { silent = false })
imap('<M-h>', '<Left>', 'Left', { noremap = false })
imap('<M-j>', '<Down>', 'Down', { noremap = false })
imap('<M-k>', '<Up>', 'Up', { noremap = false })
imap('<M-l>', '<Right>', 'Right', { noremap = false })
tmap('<M-h>', '<Left>', 'Left')
tmap('<M-j>', '<Down>', 'Down')
tmap('<M-k>', '<Up>', 'Up')
tmap('<M-l>', '<Right>', 'Right')

nmap('<C-]>', '<Cmd>bnext<CR>', 'Next buffer')
nmap('<C-[>', '<Cmd>bprevious<CR>', 'Previous buffer')
nmap('<C-n>', '<cmd>enew | startinsert<cr>', 'New buffer')
nmap('<C-c>', function() require('mini.bufremove').delete(0, false) end, 'Delete buffer')
nmap('<C-x>', function() require('neocraft.plugins.mini').open_files() end, 'Toggle file explorer')
nmap('<C-Space>', function() require('neocraft.plugins.git').toggle_overlay() end, 'Toggle diff overlay')

nmap('[<Tab>', '<Cmd>tabprevious<CR>', 'Previous tab')
nmap(']<Tab>', '<Cmd>tabnext<CR>', 'Next tab')

-- TODO: (in the future) - format (\f), inlay hints (\h). code lens (\l), minimap (\m),
nmap('\\b', toggle_background, 'Toggle background')
nmap('\\c', function() toggle_window_option('cursorline') end, 'Toggle cursorline')
nmap('\\`', toggle_conceallevel, 'Toggle conceallevel')
nmap('\\d', toggle_diagnostics, 'Toggle diagnostics')
nmap('\\h', toggle_hlsearch, 'Toggle search highlight')
nmap('\\i', function() toggle_global_option('ignorecase') end, 'Toggle ignorecase')
nmap('\\n', function() toggle_window_option('number') end, 'Toggle line numbers')
nmap('\\r', function() toggle_window_option('relativenumber') end, 'Toggle relative numbers')
nmap('\\s', function() toggle_window_option('spell') end, 'Toggle spell checking')
nmap('\\w', function() toggle_window_option('wrap') end, 'Toggle line wrap')
nmap('\\z', toggle_folds, 'Toggle folds open or closed')

-- Hot-path leader mappings
nmap_leader('f', function() require('neocraft.plugins.mini').pick_files() end, 'Find files')
nmap_leader('/', function() require('neocraft.plugins.mini').grep_live() end, 'Grep text')
nmap_leader('*', function() require('neocraft.plugins.mini').grep_cword() end, 'Grep word')
nmap_leader('r', function() require('neocraft.plugins.mini').resume_picker() end, 'Resume picker')
nmap_leader('p', function() require('neocraft.plugins.mini').pick_registry() end, 'Pickers')
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
nmap_leader('<Tab>c', '<Cmd>tabclose<CR>', 'Close tab')
nmap_leader('<Tab>d', '<Cmd>tabonly<CR>', 'Delete other tabs')

-- Git namespaces
nmap_leader('ga', function() require('neocraft.plugins.git').add_file() end, 'Add buffer')
nmap_leader('gA', function() require('neocraft.plugins.git').add_all() end, 'Add all')
nmap_leader('gb', function() require('neocraft.plugins.git').blame() end, 'Blame')
nmap_leader('gc', function() require('neocraft.plugins.git').commit() end, 'Commit')
nmap_leader('gC', function() require('neocraft.plugins.git').commit_amend() end, 'Commit amend')
nmap_leader('gd', function() require('neocraft.plugins.git').details() end, 'Details at cursor')
xmap_leader('gd', function() require('neocraft.plugins.git').details() end, 'Details at selection')
nmap_leader('gl', function() require('neocraft.plugins.git').log_repo() end, 'Log')
nmap_leader('gL', function() require('neocraft.plugins.git').log_buffer() end, 'Log buffer')
nmap_leader('gs', function() require('neocraft.plugins.git').status() end, 'Status')

nmap('[p', '<Cmd>exe "iput! " . v:register<CR>', 'Paste Above')
nmap(']p', '<Cmd>exe "iput "  . v:register<CR>', 'Paste Below')
xmap('p', 'P', 'Paste without yanking replaced selection')

nmap('<C-s>', '<Cmd>silent! update | redraw<CR>', 'Save')
imap('<C-s>', '<Esc><Cmd>silent! update | redraw<CR>', 'Save and go to Normal mode')
xmap('<C-s>', '<Esc><Cmd>silent! update | redraw<CR>', 'Save and go to Normal mode')

nmap('<Esc>', '<Cmd>nohlsearch<CR>', 'Clear search highlight')

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

tmap('<Esc><Esc>', '<C-\\><C-n>', 'Exit terminal mode')

return {
  leader_group_clues = leader_group_clues,
}
