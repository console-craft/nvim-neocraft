-- Git branch management and cleanup flows.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local util = require('neocraft.features.git.util')

-- Format a branch picker row with optional extra metadata.
local function branch_item_text(name, sha, subject, extra)
  local suffix = extra and extra ~= '' and (' [' .. extra .. ']') or ''
  return string.format('%-24s %-10s %s%s', name, sha or '-', subject or '', suffix)
end

-- Collect branch names currently checked out in any worktree.
local function checked_out_branches(repo_root)
  local result = util.run_system({ 'git', 'worktree', 'list', '--porcelain' }, {
    cwd = repo_root,
    text = true,
  })
  if result.code ~= 0 then return {} end

  local branches = {}
  for _, line in ipairs(vim.split(result.stdout or '', '\n', { plain = true })) do
    local branch = line:match('^branch refs/heads/(.+)$')
    if branch then branches[branch] = true end
  end

  return branches
end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Build picker items for deletable local branches.
function M.local_branch_items()
  local repo_root = util.git_root_or_warn()
  if repo_root == nil then return nil, 'Not inside a Git repository' end

  local current_result = util.run_system({ 'git', 'branch', '--show-current' }, {
    cwd = repo_root,
    text = true,
  })
  local current_branch = util.trim_lines(current_result.stdout)[1]
  local checked_out = checked_out_branches(repo_root)

  local result = util.run_system({
    'git',
    'for-each-ref',
    '--format=%(refname:short)\t%(objectname:short)\t%(subject)',
    'refs/heads',
  }, {
    cwd = repo_root,
    text = true,
  })
  if result.code ~= 0 then return nil, util.git_output(result) end

  local items = {}
  for _, line in ipairs(util.trim_lines(result.stdout)) do
    local parts = vim.split(line, '\t', { plain = true })
    local name, sha, subject = unpack(parts)

    if name ~= nil and name ~= current_branch and not checked_out[name] then
      table.insert(items, {
        branch = name,
        sha = sha,
        subject = subject or '',
        text = branch_item_text(name, sha, subject),
      })
    end
  end

  table.sort(items, function(a, b) return a.branch < b.branch end)
  return items, repo_root
end

-- Build picker items for deletable remote branches.
function M.remote_branch_items()
  local repo_root = util.git_root_or_warn()
  if repo_root == nil then return nil, 'Not inside a Git repository' end

  local result = util.run_system({
    'git',
    'for-each-ref',
    '--format=%(refname:short)\t%(objectname:short)\t%(subject)',
    'refs/remotes/origin',
  }, {
    cwd = repo_root,
    text = true,
  })
  if result.code ~= 0 then return nil, util.git_output(result) end

  local items = {}
  for _, line in ipairs(util.trim_lines(result.stdout)) do
    local parts = vim.split(line, '\t', { plain = true })
    local ref, sha, subject = unpack(parts)

    if ref ~= nil and ref ~= 'origin/HEAD' then
      local branch = ref:gsub('^origin/', '')
      table.insert(items, {
        branch = branch,
        ref = ref,
        sha = sha,
        subject = subject or '',
        text = branch_item_text(branch, sha, subject),
      })
    end
  end

  table.sort(items, function(a, b) return a.branch < b.branch end)
  return items, repo_root
end

-- Prompt to delete a local branch chosen from the picker.
function M.delete_local_branch()
  require('neocraft.features.pickers').git_local_branches(function(item)
    local message = ('Delete local branch %s?\n%s'):format(
      item.branch,
      item.sha and (item.sha .. ' ' .. item.subject) or ''
    )
    local choice = vim.fn.confirm(message, '&Yes\n&No', 2)
    if choice ~= 1 then return end

    local result = util.run_git({ 'branch', '-D', item.branch })
    if result == nil then return end
    if result.code ~= 0 then
      util.notify_git_failure('delete local branch', result)
      return
    end

    util.notify_git_success('Deleted local branch ' .. item.branch, result)
  end)
end

-- Prompt to delete a remote branch chosen from the picker.
function M.delete_remote_branch()
  require('neocraft.features.pickers').git_remote_branches(function(item)
    local message = ('Delete remote branch origin/%s?\n%s'):format(
      item.branch,
      item.sha and (item.sha .. ' ' .. item.subject) or ''
    )
    local choice = vim.fn.confirm(message, '&Yes\n&No', 2)
    if choice ~= 1 then return end

    local result = util.run_git({ 'push', 'origin', '--delete', item.branch })
    if result == nil then return end
    if result.code ~= 0 then
      util.notify_git_failure('delete remote branch', result)
      return
    end

    util.notify_git_success('Deleted remote branch origin/' .. item.branch, result)
  end)
end

-- Prune stale remote-tracking branches after confirmation.
function M.prune_branches()
  local choice = vim.fn.confirm('Prune stale remote branches with git fetch --prune?', '&Yes\n&No', 2)
  if choice ~= 1 then return end

  local result = util.run_git({ 'fetch', '--prune' })
  if result == nil then return end
  if result.code ~= 0 then
    util.notify_git_failure('fetch --prune', result)
    return
  end

  util.notify_git_success('Pruned stale remote branches', result)
end

return M
