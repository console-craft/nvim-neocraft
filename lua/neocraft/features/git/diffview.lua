-- Diffview-backed Git workflows.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local working_only_next_view = false

local function consume_working_only_next_view()
  local value = working_only_next_view
  working_only_next_view = false

  return value
end

local function is_diff_view(view)
  return type(view) == 'table'
    and type(view.class) == 'table'
    and type(view.class.name) == 'function'
    and view.class:name() == 'DiffView'
end

local function includes_file(files, target)
  for _, file in ipairs(files or {}) do
    if file == target then return true end
  end

  return false
end

local function filter_staged_files(view)
  if not is_diff_view(view) or type(view.files) ~= 'table' or type(view.panel) ~= 'table' then return end
  if type(view.files.staged) ~= 'table' or #view.files.staged == 0 then return end

  view.files:set_staged({})
  view.files:update_file_trees()
  view.panel:update_components()
  view.panel:render()
  view.panel:redraw()

  if type(view.panel.reconstrain_cursor) == 'function' then view.panel:reconstrain_cursor() end

  if view.files:len() == 0 then
    view.panel:set_cur_file(nil)
    if type(view.file_safeguard) == 'function' then view:file_safeguard() end
    return
  end

  local files = view.panel:ordered_file_list()
  if not includes_file(files, view.panel.cur_file) then view:set_file(files[1], false, true) end
end

local function use_working_only_file_panel(view)
  if not consume_working_only_next_view() then return end
  if not is_diff_view(view) or type(view.emitter) ~= 'table' or type(view.emitter.on) ~= 'function' then return end

  view.emitter:on('files_updated', function() filter_staged_files(view) end)
end

local function close_diffview() vim.cmd.DiffviewClose() end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

function M.open_diff()
  working_only_next_view = true

  local ok, err = pcall(vim.cmd.DiffviewOpen)
  if ok then return end

  working_only_next_view = false
  error(err)
end

function M.open_staged_diff() vim.cmd('DiffviewOpen --cached') end

function M.open_working_tree_diff() vim.cmd.DiffviewOpen() end

function M.open_log() vim.cmd.DiffviewFileHistory() end

function M.open_file_history() vim.cmd('DiffviewFileHistory %') end

function M.refresh_buffers(view)
  vim.schedule(function()
    local ok, clue = pcall(require, 'mini.clue')
    local ok_lsp, lsp = pcall(require, 'neocraft.features.lsp')
    if type(view.tabpage) ~= 'number' or not vim.api.nvim_tabpage_is_valid(view.tabpage) then return end

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(view.tabpage)) do
      if vim.api.nvim_win_is_valid(win) then
        local buf = vim.api.nvim_win_get_buf(win)
        if ok then clue.ensure_buf_triggers(buf) end
        if ok_lsp then lsp.reset_buffer_annotations(buf) end
      end
    end
  end)
end

function M.on_view_opened(view)
  use_working_only_file_panel(view)
  M.refresh_buffers(view)
end

function M.hooks()
  return {
    view_opened = M.on_view_opened,
    view_post_layout = M.refresh_buffers,
  }
end

function M.keymaps()
  local actions = require('diffview.config').actions

  return {
    view = {
      { 'n', '<leader>e', actions.toggle_files, { desc = 'Toggle explorer' } },
      { 'n', '<leader>b', false },
      { 'n', '<leader>co', false },
      { 'n', '<leader>ct', false },
      { 'n', '<leader>cb', false },
      { 'n', '<leader>ca', false },
      { 'n', '<leader>cO', false },
      { 'n', '<leader>cT', false },
      { 'n', '<leader>cB', false },
      { 'n', '<leader>cA', false },
      { 'n', '<leader>q', close_diffview, { desc = 'Quit DiffView' } },
      { 'n', '<localleader>co', actions.conflict_choose('ours'), { desc = 'Choose the OURS version of a conflict' } },
      {
        'n',
        '<localleader>ct',
        actions.conflict_choose('theirs'),
        { desc = 'Choose the THEIRS version of a conflict' },
      },
      { 'n', '<localleader>cb', actions.conflict_choose('base'), { desc = 'Choose the BASE version of a conflict' } },
      { 'n', '<localleader>ca', actions.conflict_choose('all'), { desc = 'Choose all the versions of a conflict' } },
      {
        'n',
        '<localleader>cO',
        actions.conflict_choose_all('ours'),
        { desc = 'Choose the OURS version of a conflict for the whole file' },
      },
      {
        'n',
        '<localleader>cT',
        actions.conflict_choose_all('theirs'),
        { desc = 'Choose the THEIRS version of a conflict for the whole file' },
      },
      {
        'n',
        '<localleader>cB',
        actions.conflict_choose_all('base'),
        { desc = 'Choose the BASE version of a conflict for the whole file' },
      },
      {
        'n',
        '<localleader>cA',
        actions.conflict_choose_all('all'),
        { desc = 'Choose all the versions of a conflict for the whole file' },
      },
    },
    file_panel = {
      { 'n', '<leader>e', actions.toggle_files, { desc = 'Toggle explorer' } },
      { 'n', '<leader>b', false },
      { 'n', '<leader>cO', false },
      { 'n', '<leader>cT', false },
      { 'n', '<leader>cB', false },
      { 'n', '<leader>cA', false },
      { 'n', '<leader>q', close_diffview, { desc = 'Quit DiffView' } },
      {
        'n',
        '<localleader>cO',
        actions.conflict_choose_all('ours'),
        { desc = 'Choose the OURS version of a conflict for the whole file' },
      },
      {
        'n',
        '<localleader>cT',
        actions.conflict_choose_all('theirs'),
        { desc = 'Choose the THEIRS version of a conflict for the whole file' },
      },
      {
        'n',
        '<localleader>cB',
        actions.conflict_choose_all('base'),
        { desc = 'Choose the BASE version of a conflict for the whole file' },
      },
      {
        'n',
        '<localleader>cA',
        actions.conflict_choose_all('all'),
        { desc = 'Choose all the versions of a conflict for the whole file' },
      },
    },
    file_history_panel = {
      { 'n', '<leader>e', actions.toggle_files, { desc = 'Toggle explorer' } },
      { 'n', '<leader>b', false },
      { 'n', '<leader>q', close_diffview, { desc = 'Quit DiffView' } },
    },
  }
end

return M
