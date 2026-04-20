-- Common Git commands and file-scoped actions.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local util = require('neocraft.features.git.util')

-- Warn when a Git action requires a file-backed buffer.
local function notify_missing_file(action) vim.notify('No file context for Git ' .. action, vim.log.levels.WARN) end

-- Check whether the buffer points to a real file on disk.
local function has_file_context(buf)
  buf = util.resolve_buf(buf)

  return vim.bo[buf].buftype == '' and vim.api.nvim_buf_get_name(buf) ~= ''
end

-- Save a buffer with `:update`, returning whether it succeeded.
local function save_buffer(buf)
  buf = util.resolve_buf(buf)

  return vim.api.nvim_buf_call(buf, function()
    return pcall(function() vim.cmd('silent update') end)
  end)
end

-- Collect all modified file-backed buffers.
local function unsaved_file_buffers()
  local result = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_valid(buf)
      and vim.bo[buf].buftype == ''
      and vim.api.nvim_buf_get_name(buf) ~= ''
      and vim.bo[buf].modified
    then
      table.insert(result, buf)
    end
  end

  return result
end

-- Collect files with staged changes, preserving both paths for renames and copies.
local function staged_file_items(repo_root)
  local result = util.run_system({ 'git', 'diff', '--cached', '--name-status', '-z' }, {
    cwd = repo_root,
    text = true,
  })
  if result.code ~= 0 then return nil, result end

  local tokens = {}
  for token in (result.stdout or ''):gmatch('([^%z]+)') do
    table.insert(tokens, token)
  end

  local items = {}
  local i = 1
  while i <= #tokens do
    local status = tokens[i]
    local code = status:sub(1, 1)
    local path = tokens[i + 1]
    local source_path = nil
    local paths = { path }

    if code == 'R' or code == 'C' then
      source_path = tokens[i + 1]
      path = tokens[i + 2]
      paths = code == 'R' and { source_path, path } or { path }
      i = i + 1
    end

    if path ~= nil and path ~= '' then
      local text = ('%-5s %s'):format(status, path)
      if source_path ~= nil then text = ('%-5s %s -> %s'):format(status, source_path, path) end

      table.insert(items, {
        path = path,
        paths = paths,
        text = text,
      })
    end

    i = i + 2
  end

  return items
end

-- Unstage one or more staged picker items.
local function unstage_items(repo_root, items)
  local path_args = {}
  for _, item in ipairs(items) do
    for _, path in ipairs(item.paths or { item.path }) do
      if path ~= nil and path ~= '' then table.insert(path_args, path) end
    end
  end
  if #path_args == 0 then return end

  local result = util.run_git(vim.list_extend({ 'restore', '--staged', '--' }, path_args), { cwd = repo_root })
  if result == nil then return end
  if result.code ~= 0 then
    util.notify_git_failure('restore --staged', result)
    return
  end

  local count = #items
  util.notify_git_success(('Unstaged %d file%s'):format(count, count == 1 and '' or 's'), result)
end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Stage the current file after saving it.
function M.add_file()
  if not has_file_context() then
    notify_missing_file('add')
    return
  end

  local ok = save_buffer(0)
  if not ok then return end

  util.git('add -- %')
end

-- Stage all tracked and untracked changes after confirming unsaved buffers.
function M.add_all()
  local unsaved = unsaved_file_buffers()
  if #unsaved > 0 then
    local message = ('You have unsaved changes in %d buffer%s. Stage only saved changes?'):format(
      #unsaved,
      #unsaved == 1 and '' or 's'
    )
    local choice = vim.fn.confirm(message, '&Yes\n&No', 2)
    if choice ~= 1 then return end
  end

  util.git('add -A')
end

-- Start a Git commit in the current repository.
function M.commit() util.git('commit') end

-- Start an amended Git commit in the current repository.
function M.commit_amend() util.git('commit --amend') end

-- Show repository status in a Git buffer.
function M.status() util.git('status') end

-- Open contextual git-related data under the cursor.
function M.open() require('mini.git').show_at_cursor({ split = 'auto' }) end

-- Unstage every currently staged file after confirmation.
function M.unstage_all()
  local repo_root = util.git_root_or_warn()
  if repo_root == nil then return end

  local items, err = staged_file_items(repo_root)
  if items == nil then
    util.notify_git_failure('diff --cached --name-status', err)
    return
  end
  if #items == 0 then
    vim.notify('No staged files to unstage', vim.log.levels.INFO)
    return
  end

  local choice =
    vim.fn.confirm(('Unstage all %d staged file%s?'):format(#items, #items == 1 and '' or 's'), '&Yes\n&No', 2)
  if choice ~= 1 then return end

  local result = util.run_git({ 'restore', '--staged', '.' }, { cwd = repo_root })
  if result == nil then return end
  if result.code ~= 0 then
    util.notify_git_failure('restore --staged .', result)
    return
  end

  util.notify_git_success('Unstaged all files', result)
end

-- Pick one or more staged files to unstage.
function M.unstage_file()
  local repo_root = util.git_root_or_warn()
  if repo_root == nil then return end

  local items, err = staged_file_items(repo_root)
  if items == nil then
    util.notify_git_failure('diff --cached --name-status', err)
    return
  end
  if #items == 0 then
    vim.notify('No staged files to unstage', vim.log.levels.INFO)
    return
  end

  return require('mini.pick').start({
    source = {
      items = items,
      name = 'Unstage Files | <C-x> = select item | <M-CR> = confirm selected',
      choose = function(item)
        if type(item) ~= 'table' then return end
        vim.schedule(function() unstage_items(repo_root, { item }) end)
      end,
      choose_marked = function(items_marked)
        if #items_marked == 0 then return end
        vim.schedule(function() unstage_items(repo_root, items_marked) end)
      end,
    },
  })
end

return M
