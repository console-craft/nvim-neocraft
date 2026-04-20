local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local root = require('neocraft.core.root')

local focus_label = 'focus'

local function resolve_buf(buf) return (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf end

local function current_path(buf) return root.bufpath(resolve_buf(buf)) end

local function has_file_context(buf)
  buf = resolve_buf(buf)
  return vim.bo[buf].buftype == '' and current_path(buf) ~= nil
end

local function notify_missing_file(action) vim.notify('No file context for focus ' .. action, vim.log.levels.WARN) end

local function focus_filter(path_data) return path_data.labels ~= nil and path_data.labels[focus_label] == true end

local function current_root(buf)
  local cwd = root.get({ buf = resolve_buf(buf) })
  return cwd and root.realpath(cwd) or nil
end

local function notify_missing_project(action) vim.notify('No project root for focus ' .. action, vim.log.levels.WARN) end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

function M.pick_focus(buf)
  buf = resolve_buf(buf)

  local cwd = current_root(buf)
  if cwd == nil then
    notify_missing_file('pick')
    return
  end

  local mini_visits = require('mini.visits')
  local sort_latest = mini_visits.gen_sort.default({ recency_weight = 1 })
  local paths = mini_visits.list_paths(cwd, { filter = focus_filter, sort = sort_latest })
  if #paths == 0 then
    vim.notify('Focus list is empty for this project', vim.log.levels.INFO)
    return
  end

  require('mini.extra').pickers.visit_paths({
    cwd = cwd,
    filter = focus_label,
    sort = sort_latest,
  }, {
    source = { name = 'Focus List' },
  })
end

function M.add_focus(buf)
  buf = resolve_buf(buf)
  if not has_file_context(buf) then
    notify_missing_file('add')
    return
  end

  local path = current_path(buf)
  local cwd = current_root(buf)
  require('mini.visits').add_label(focus_label, path, cwd)
  require('mini.visits').write_index()
  vim.notify('Added file to focus list', vim.log.levels.INFO)
end

function M.remove_focus(buf)
  buf = resolve_buf(buf)
  if not has_file_context(buf) then
    notify_missing_file('remove')
    return
  end

  local path = current_path(buf)
  local cwd = current_root(buf)
  require('mini.visits').remove_label(focus_label, path, cwd)
  require('mini.visits').write_index()
  vim.notify('Deleted file from focus list', vim.log.levels.INFO)
end

function M.remove_all_focus(buf)
  local cwd = current_root(buf)
  if cwd == nil then
    notify_missing_project('delete all')
    return
  end

  local mini_visits = require('mini.visits')
  local paths = mini_visits.list_paths(cwd, { filter = focus_filter })
  if #paths == 0 then
    vim.notify('Focus list is already empty for this project', vim.log.levels.INFO)
    return
  end

  mini_visits.remove_label(focus_label, '', cwd)
  mini_visits.write_index()
  vim.notify('Cleared focus list', vim.log.levels.INFO)
end

function M.clear_focus_list(buf)
  local choice = vim.fn.confirm('Clear focus list?', '&Yes\n&No\n&Cancel', 2)
  if choice == 1 then M.remove_all_focus(buf) end
end

return M
