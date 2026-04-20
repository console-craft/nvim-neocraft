local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Toggle                                    │
-- └───────────────────────────────────────────┘

-- Show a transient status message for a toggle.
local function show_toggle_state(text) vim.api.nvim_echo({ { text, 'Normal' } }, false, {}) end

-- Build standardized enabled/disabled toggle text.
local function get_toggle_text(name, enabled) return (enabled and 'Enabled: ' or 'Disabled: ') .. name end

-- Toggle a window-local option and report its new state.
function M.toggle_window_option(name)
  local enabled = vim.api.nvim_get_option_value(name, { scope = 'local', win = 0 }) == true
  local toggled = not enabled

  vim.api.nvim_set_option_value(name, toggled, { scope = 'local', win = 0 })
  show_toggle_state(get_toggle_text(name, toggled))
end

-- Toggle a global option and report its new state.
function M.toggle_global_option(name)
  vim.o[name] = not vim.o[name]
  show_toggle_state(get_toggle_text(name, vim.o[name]))
end

-- Toggle format-on-save and report its new state.
function M.toggle_format_on_save()
  vim.g.enable_format_on_save = vim.g.enable_format_on_save ~= true
  show_toggle_state(get_toggle_text('format on save', vim.g.enable_format_on_save))
end

-- Toggle between dark and light background.
function M.toggle_background()
  vim.o.background = vim.o.background == 'dark' and 'light' or 'dark'
  show_toggle_state('Background: ' .. vim.o.background)
end

-- Toggle conceal rendering, including markdown preview buffers.
function M.toggle_conceallevel()
  local bufnr = vim.api.nvim_get_current_buf()

  if vim.bo[bufnr].filetype == 'markdown' then
    local render_markdown = require('render-markdown')
    local render_markdown_state = require('render-markdown.state')
    local enabled = render_markdown_state.get(bufnr).enabled

    render_markdown.buf_toggle()
    show_toggle_state(get_toggle_text('markdown render', not enabled))
    return
  end

  if vim.wo.conceallevel == 0 then
    vim.wo.conceallevel = 3
    vim.opt_local.concealcursor = 'n'
  else
    vim.wo.conceallevel = 0
    vim.opt_local.concealcursor = ''
  end
  show_toggle_state('Conceal Level: ' .. vim.wo.conceallevel)
end

-- Toggle diagnostics for the current buffer.
function M.toggle_diagnostics()
  local bufnr = vim.api.nvim_get_current_buf()
  local enabled = vim.diagnostic.is_enabled({ bufnr = bufnr })

  vim.diagnostic.enable(not enabled, { bufnr = bufnr })
  show_toggle_state(get_toggle_text('diagnostic', not enabled))
end

-- Toggle all folds open or closed in the current window.
function M.toggle_folds()
  local opening = vim.wo.foldlevel == 0

  vim.cmd('normal! ' .. (opening and 'zR' or 'zM'))
  show_toggle_state(opening and 'Folds: all opened' or 'Folds: all closed')
end

-- Return the key sequence that toggles the current fold.
function M.toggle_current_fold() return 'zA' end

-- ┌───────────────────────────────────────────┐
-- │ List                                      │
-- └───────────────────────────────────────────┘

-- Open a list window and report failures.
local function open_list(cmd)
  local success, err = pcall(cmd)
  if not success and err then vim.notify(err, vim.log.levels.ERROR) end
end

-- Open the quickfix list.
function M.open_quickfix_list() open_list(vim.cmd.copen) end

-- Populate and open the current window's location list.
function M.open_location_list()
  vim.diagnostic.setloclist()
  open_list(vim.cmd.lopen)
end

-- Show the notification history in a new tab.
function M.show_notifications()
  vim.cmd.tabnew()
  require('mini.notify').show_history()
end

-- ┌───────────────────────────────────────────┐
-- │ Dismiss UI                                │
-- └───────────────────────────────────────────┘

-- Clear visible non-progress notifications.
local function clear_notifications_on_escape()
  local ok, notify = pcall(require, 'mini.notify')
  if not ok then return end

  for id, notif in pairs(notify.get_all()) do
    if notif.ts_remove == nil and not (type(notif.data) == 'table' and notif.data.source == 'lsp_progress') then
      notify.remove(id)
    end
  end
end

-- Clear the command-line message area.
local function clear_cmdline_on_escape()
  vim.api.nvim_echo({ { '' } }, false, {})
  vim.cmd.redraw()
end

local editing = require('neocraft.features.editing')

-- Clear search, command-line messages, minimap state, and notifications.
function M.clear_on_escape()
  vim.cmd.nohlsearch()
  editing.clear_inline_search_count()
  clear_cmdline_on_escape()

  local ok, map = pcall(require, 'mini.map')
  if ok then map.refresh() end

  clear_notifications_on_escape()
end

-- ┌───────────────────────────────────────────┐
-- │ Title                                     │
-- └───────────────────────────────────────────┘

local root = require('neocraft.core.root')
local title_git_cache = {}

local function title_start_path()
  local path = vim.api.nvim_buf_get_name(0)
  if path ~= '' then return vim.fs.dirname(path) end

  return vim.uv.cwd() or vim.fn.getcwd()
end

local function run_title_git(start, args)
  if start == nil or start == '' then return nil end

  local result = vim.system(vim.list_extend({ 'git', '-C', start }, args), { text = true }):wait()
  if result.code ~= 0 then return nil end

  local output = vim.trim(result.stdout or '')
  return output ~= '' and output or nil
end

local function title_git_branch()
  local start = title_start_path()
  local cached = title_git_cache[start]
  if cached ~= nil then return cached ~= false and cached or nil end

  local git_root = run_title_git(start, { 'rev-parse', '--show-toplevel' })
  if git_root == nil then
    title_git_cache[start] = false
    return nil
  end

  cached = title_git_cache[git_root]
  if cached ~= nil then
    title_git_cache[start] = cached
    return cached ~= false and cached or nil
  end

  local branch = run_title_git(git_root, { 'branch', '--show-current' })
  if branch == nil then
    local head = run_title_git(git_root, { 'rev-parse', '--short', 'HEAD' })
    branch = head and ('@' .. head) or nil
  end

  title_git_cache[git_root] = branch or false
  title_git_cache[start] = branch or false
  return branch
end

-- Update the terminal title with the current project and Git branch.
function M.update_terminal_title()
  local cwd = vim.uv.cwd()
  local cwd_name = cwd and vim.fs.basename(cwd) or '[No CWD]'
  local branch = title_git_branch()
  local branch_title = branch and (' → ' .. branch) or ''

  vim.opt.titlestring = string.format('%s%s', cwd_name, branch_title)
end

-- Clear cached Git branch information used for terminal titles.
function M.clear_title_git_cache() title_git_cache = {} end

local function relative_to_root(path, root_dir)
  if path == root_dir then return vim.fs.basename(path) end
  if vim.startswith(path, root_dir .. '/') then return path:sub(#root_dir + 2) end
  return nil
end

local function fallback_winbar_label(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= '' then return vim.fs.basename(name) end

  local filetype = vim.bo[bufnr].filetype
  if filetype ~= '' then return '    󰈔  [' .. filetype .. ']' end

  return '    󰈔  [No Name]'
end

-- Render the current window bar with the current file path relative to the project root.
function M.render_winbar()
  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == '' then return fallback_winbar_label(bufnr) end

  local root_dir = root.get({ buf = bufnr })
  local root_name = root_dir and vim.fs.basename(root_dir) or nil
  local relative = root_dir and relative_to_root(path, root_dir) or nil

  if root_name and relative and relative ~= '' then return '    󰈔  [' .. root_name .. '] → ' .. relative end
  if root_name then return '    󰈔  [' .. root_name .. '] → ' .. vim.fs.basename(path) end

  return fallback_winbar_label(bufnr)
end

-- ┌───────────────────────────────────────────┐
-- │ Session                                   │
-- └───────────────────────────────────────────┘

-- Restart Neovim, optionally discarding the current project session.
local function restart(keep_session)
  if keep_session == false then
    local sessions = require('neocraft.core.sessions')
    sessions.discard_once()
    sessions.delete_current()
  end

  vim.defer_fn(function() vim.cmd('confirm restart') end, 500)
end

-- Prompt for session handling and restart Neovim.
function M.restart_neovim()
  local choice = vim.fn.confirm('Keep session for this project?', '&Yes\n&No', 1)
  if choice == 0 then return end

  restart(choice == 1)
end

-- Check whether any valid buffer has unsaved changes.
local function has_modified_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then return true end
  end

  return false
end

-- Confirm and quit Neovim, warning when buffers are modified.
function M.quit_neovim()
  local msg = has_modified_buffers() and 'You have unsaved changes! Quit anyway?' or 'Quit Neovim?'
  local choice = vim.fn.confirm(msg, '&Yes\n&No\n&Cancel', 2)
  if choice == 1 then vim.api.nvim_cmd({ cmd = 'qall', bang = true }, {}) end
end

return M
