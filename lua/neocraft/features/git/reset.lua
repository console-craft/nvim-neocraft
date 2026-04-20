-- Git reset and worktree cleanup flows.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local util = require('neocraft.features.git.util')

-- Warn that modified buffers block a destructive Git action.
local function notify_modified_buffers(action)
  vim.notify('Save or discard modified buffers before ' .. action, vim.log.levels.WARN)
end

-- Check whether any loaded buffer has unsaved changes.
local function has_unsaved_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then return true end
  end

  return false
end

-- Return a short summary of the current HEAD commit.
local function current_head_summary(repo_root)
  local result = util.run_system({ 'git', 'log', '-1', '--format=%h %s' }, {
    cwd = repo_root,
    text = true,
  })
  if result.code ~= 0 then return 'HEAD' end

  return util.trim_lines(result.stdout)[1] or 'HEAD'
end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Hard-reset the latest commit after confirmation.
function M.reset_latest_commit_hard()
  if has_unsaved_buffers() then
    notify_modified_buffers('running git reset --hard HEAD~1')
    return
  end

  local repo_root = util.git_root_or_warn()
  if repo_root == nil then return end

  local head = current_head_summary(repo_root)
  local choice =
    vim.fn.confirm(('Discard latest commit and tracked changes from disk?\n%s'):format(head), '&Yes\n&No', 2)
  if choice ~= 1 then return end

  local result = util.run_git({ 'reset', '--hard', 'HEAD~1' }, { cwd = repo_root })
  if result == nil then return end
  if result.code ~= 0 then
    util.notify_git_failure('reset --hard HEAD~1', result)
    return
  end

  util.notify_git_success('Discarded latest commit and tracked changes', result)
end

-- Remove the latest commit while keeping its changes unstaged.
function M.reset_latest_commit_mixed()
  local repo_root = util.git_root_or_warn()
  if repo_root == nil then return end

  local head = current_head_summary(repo_root)
  local choice = vim.fn.confirm(('Remove latest commit and keep changes unstaged?\n%s'):format(head), '&Yes\n&No', 2)
  if choice ~= 1 then return end

  local result = util.run_git({ 'reset', '--mixed', 'HEAD~1' }, { cwd = repo_root })
  if result == nil then return end
  if result.code ~= 0 then
    util.notify_git_failure('reset --mixed HEAD~1', result)
    return
  end

  util.notify_git_success('Removed latest commit and kept changes unstaged', result)
end

-- Hard-reset tracked changes and delete untracked files after confirmation.
function M.reset_and_clean()
  if has_unsaved_buffers() then
    notify_modified_buffers('running git reset --hard && git clean -fd')
    return
  end

  local repo_root = util.git_root_or_warn()
  if repo_root == nil then return end

  local choice = vim.fn.confirm(
    'Discard tracked changes and delete untracked files/directories from disk?\nThis cannot be undone.',
    '&Yes\n&No',
    2
  )
  if choice ~= 1 then return end

  local reset_result = util.run_git({ 'reset', '--hard' }, { cwd = repo_root })
  if reset_result == nil then return end
  if reset_result.code ~= 0 then
    util.notify_git_failure('reset --hard', reset_result)
    return
  end

  local clean_result = util.run_git({ 'clean', '-fd' }, { cwd = repo_root })
  if clean_result == nil then return end
  if clean_result.code ~= 0 then
    util.notify_git_failure('clean -fd', clean_result)
    return
  end

  local output = table.concat(
    vim.tbl_filter(function(part) return part ~= '' end, {
      util.git_output(reset_result),
      util.git_output(clean_result),
    }),
    '\n'
  )
  if output ~= '' then
    vim.notify('Reset tracked changes and cleaned untracked files\n' .. output, vim.log.levels.INFO)
    return
  end

  vim.notify('Reset tracked changes and cleaned untracked files', vim.log.levels.INFO)
end

return M
