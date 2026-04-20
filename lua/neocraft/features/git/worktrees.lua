local M = {}

---@class neocraft.git.WorktreeItem
---@field path string
---@field name string
---@field text string
---@field head? string
---@field branch? string
---@field branch_ref? string
---@field detached? boolean
---@field locked? boolean|string
---@field prunable? boolean|string
---@field bare? boolean
---@field is_current boolean
---@field is_main boolean

---@class neocraft.git.RepoInfo
---@field common_dir string
---@field current_root string
---@field main_root string
---@field repo_slug string
---@field repo_dir string

---@class neocraft.git.FileItem
---@field path string
---@field relative_path string
---@field text string

---@class neocraft.git.BaseItem
---@field kind string
---@field label string
---@field text string
---@field value? string

---@class neocraft.git.WorktreeOpts
---@field buf? integer
---@field cwd? string

local WORKTREES_BASE_DIR = '~/.worktrees'

-- ┌───────────────────────────────────────────┐
-- │ Helpers                                   │
-- └───────────────────────────────────────────┘

---@param item neocraft.git.WorktreeItem
---@return string
local function worktree_text(item)
  local role = item.is_main and 'main' or 'tree'
  local branch = item.branch or (item.detached and 'detached' or '')
  local head = item.head and item.head:sub(1, 8) or '-'
  local flags = {}

  if item.is_current then table.insert(flags, 'current') end
  if item.locked then table.insert(flags, 'locked') end
  if item.prunable then table.insert(flags, 'prunable') end

  local suffix = #flags > 0 and (' [' .. table.concat(flags, ', ') .. ']') or ''

  return string.format('%-5s %-22s %-18s %-8s %s%s', role, item.name, branch, head, item.path, suffix)
end

---@param item neocraft.git.WorktreeItem
---@param info neocraft.git.RepoInfo
---@return string
local function worktree_name(item, info)
  if item.path == info.main_root then return 'main' end

  local relative = vim.fs.relpath(info.repo_dir, item.path)
  if relative and relative ~= '' and not vim.startswith(relative, '..') then return relative end

  return vim.fs.basename(item.path)
end

local root = require('neocraft.core.root')

---@param path? string
---@return string?
local function normalize(path)
  if path == nil or path == '' then return nil end
  return root.realpath(path) or vim.fs.normalize(path)
end

---@param output? string
---@param info neocraft.git.RepoInfo
---@return neocraft.git.WorktreeItem[]
local function parse_worktrees(output, info)
  local items = {}
  local current = nil

  for _, line in ipairs(vim.split(output or '', '\n', { plain = true })) do
    if line == '' then
      current = nil
    elseif vim.startswith(line, 'worktree ') then
      current = { path = normalize(line:sub(#'worktree ' + 1)) }
      table.insert(items, current)
    elseif current ~= nil then
      local key, value = line:match('^(%S+)%s*(.*)$')

      if key == 'HEAD' then current.head = value end
      if key == 'branch' then
        current.branch_ref = value
        current.branch = value:gsub('^refs/heads/', '')
      end
      if key == 'detached' then current.detached = true end
      if key == 'locked' then current.locked = value ~= '' and value or true end
      if key == 'prunable' then current.prunable = value ~= '' and value or true end
      if key == 'bare' then current.bare = true end
    end
  end

  for _, item in ipairs(items) do
    item.is_current = item.path == info.current_root
    item.is_main = item.path == info.main_root
    item.name = worktree_name(item, info)
    item.text = worktree_text(item)
  end

  table.sort(items, function(a, b)
    if a.is_main ~= b.is_main then return a.is_main end
    return a.path < b.path
  end)

  return items
end

---@param cmd string[]
---@param opts? table
---@return vim.SystemCompleted
local function run_system(cmd, opts) return vim.system(cmd, opts or {}):wait() end

---@param args string[]
---@param opts? neocraft.git.WorktreeOpts
---@return neocraft.git.SystemResult
local function run_git(args, opts)
  opts = opts or {}

  return run_system(vim.list_extend({ 'git' }, args), {
    cwd = opts.cwd or root.git({ buf = opts.buf }),
    text = true,
  })
end

---@param text? string
---@return string[]
local function trim_lines(text)
  text = (text or ''):gsub('%s+$', '')
  return text == '' and {} or vim.split(text, '\n', { trimempty = true })
end

local function base_dir() return vim.fs.normalize(vim.fn.expand(WORKTREES_BASE_DIR)) end

local function sanitize(path) return (path:gsub('[^%w%.%-_]+', '_')) end

---@param result neocraft.git.SystemResult
---@return neocraft.git.RepoInfo?
local function repo_info_from_result(result)
  if result.code ~= 0 then return nil end

  local lines = trim_lines(result.stdout)
  if #lines < 2 then return nil end

  local common_dir = normalize(lines[1])
  local current_root = normalize(lines[2])
  local main_root = common_dir and normalize(vim.fs.dirname(common_dir)) or nil
  if common_dir == nil or current_root == nil or main_root == nil then return nil end

  local repo_slug = sanitize(main_root)

  return {
    common_dir = common_dir,
    current_root = current_root,
    main_root = main_root,
    repo_slug = repo_slug,
    repo_dir = vim.fs.joinpath(base_dir(), repo_slug),
  }
end

---@param opts? neocraft.git.WorktreeOpts
---@return neocraft.git.RepoInfo?
local function repo_info(opts)
  opts = opts or {}

  return repo_info_from_result(
    run_git({ 'rev-parse', '--path-format=absolute', '--git-common-dir', '--show-toplevel' }, opts)
  )
end

-- ┌───────────────────────────────────────────┐
-- │ List                                      │
-- └───────────────────────────────────────────┘

---@param opts? neocraft.git.WorktreeOpts
---@return neocraft.git.WorktreeItem[]? items
---@return neocraft.git.RepoInfo|string info_or_err
function M.list(opts)
  opts = opts or {}

  local info = repo_info(opts)
  if info == nil then return nil, 'Not inside a Git repository' end

  local result = run_git({ 'worktree', 'list', '--porcelain' }, {
    buf = opts.buf,
    cwd = info.current_root,
  })
  if result.code ~= 0 then return nil, vim.trim(result.stderr or result.stdout or '') end

  return parse_worktrees(result.stdout, info), info
end

-- ┌───────────────────────────────────────────┐
-- │ Project file items                        │
-- └───────────────────────────────────────────┘

---@param cwd string
---@return neocraft.git.FileItem[]
local function files_from_fs(cwd)
  local items = {}

  for relative_path, file_type in vim.fs.dir(cwd, { depth = math.huge }) do
    if file_type == 'file' and relative_path ~= '.git' and not vim.startswith(relative_path, '.git/') then
      table.insert(items, {
        path = vim.fs.joinpath(cwd, relative_path),
        relative_path = relative_path,
        text = relative_path,
      })
    end
  end

  return items
end

---@param cwd string
---@return neocraft.git.FileItem[]?
local function files_from_fd(cwd)
  if vim.fn.executable('fd') ~= 1 then return nil end

  local result = run_system({ 'fd', '--type', 'f', '--hidden', '--no-ignore', '--exclude', '.git', '.' }, {
    cwd = cwd,
    text = true,
  })
  if result.code ~= 0 then return nil end

  local items = {}
  for _, relative_path in ipairs(trim_lines(result.stdout)) do
    table.insert(items, {
      path = vim.fs.joinpath(cwd, relative_path),
      relative_path = relative_path,
      text = relative_path,
    })
  end

  return items
end

---@param opts? neocraft.git.WorktreeOpts
---@return neocraft.git.FileItem[]? items
---@return neocraft.git.RepoInfo|string info_or_err
function M.project_file_items(opts)
  opts = opts or {}

  local info = repo_info(opts)
  if info == nil then return nil, 'Not inside a Git repository' end

  local items = files_from_fd(info.current_root) or files_from_fs(info.current_root)
  table.sort(items, function(a, b) return a.relative_path < b.relative_path end)

  return items, info
end

-- ┌───────────────────────────────────────────┐
-- │ Base items                                │
-- └───────────────────────────────────────────┘

---@param items neocraft.git.BaseItem[]
---@param seen table<string, boolean>
---@param item neocraft.git.BaseItem
local function add_unique_item(items, seen, item)
  if item.value == nil or seen[item.value] then return end

  seen[item.value] = true
  table.insert(items, item)
end

---@param opts? neocraft.git.WorktreeOpts
---@return neocraft.git.BaseItem[]? items
---@return neocraft.git.RepoInfo|string info_or_err
function M.base_items(opts)
  opts = opts or {}

  local info = repo_info(opts)
  if info == nil then return nil, 'Not inside a Git repository' end

  local items, seen = {}, {}
  local head = run_git({ 'rev-parse', '--short', 'HEAD' }, { cwd = info.current_root })
  local head_short = trim_lines(head.stdout)[1] or 'HEAD'

  add_unique_item(items, seen, {
    kind = 'head',
    value = 'HEAD',
    label = 'HEAD',
    text = string.format('%-8s %-20s %s', 'HEAD', 'HEAD', 'current HEAD (' .. head_short .. ')'),
  })

  table.insert(items, {
    kind = 'custom',
    label = 'custom',
    text = string.format('%-8s %s', 'custom', 'Enter commit-ish manually...'),
  })

  local refs = run_git({
    'for-each-ref',
    '--format=%(refname:short)\t%(objectname:short)\t%(subject)\t%(refname)',
    'refs/heads',
    'refs/tags',
  }, { cwd = info.current_root })

  if refs.code == 0 then
    for _, line in ipairs(trim_lines(refs.stdout)) do
      local name, sha, subject, full_ref = unpack(vim.split(line, '\t', { plain = true }))
      local kind = full_ref and full_ref:find('^refs/tags/') and 'tag' or 'branch'
      local summary = subject and subject ~= '' and subject or sha or ''

      add_unique_item(items, seen, {
        kind = kind,
        value = full_ref or name,
        label = name,
        text = string.format('%-8s %-20s %s', kind, name or '', summary),
      })
    end
  end

  local commits = run_git({ 'log', '--decorate', '--oneline', '--all', '-n', '50' }, { cwd = info.current_root })
  if commits.code == 0 then
    for _, line in ipairs(trim_lines(commits.stdout)) do
      local sha = line:match('^(%S+)')

      add_unique_item(items, seen, {
        kind = 'commit',
        value = sha,
        label = sha,
        text = string.format('%-8s %s', 'commit', line),
      })
    end
  end

  return items, info
end

-- ┌───────────────────────────────────────────┐
-- │ Prompt helpers                            │
-- └───────────────────────────────────────────┘

local function notify_git_error(action, result)
  local output = vim.trim(table.concat(
    vim.tbl_filter(function(part) return part ~= nil and part ~= '' end, {
      result and result.stderr or nil,
      result and result.stdout or nil,
    }),
    '\n'
  ))

  if output == '' then output = 'Git ' .. action .. ' failed' end
  vim.notify(output, vim.log.levels.ERROR)
end

local function notify_not_git() vim.notify('Not inside a Git repository', vim.log.levels.WARN) end

---@param buf? integer
---@return neocraft.git.RepoInfo?
local function ensure_repo_info(buf)
  local info = repo_info({ buf = buf })
  if info ~= nil then return info end

  notify_not_git()
  return nil
end

-- ┌───────────────────────────────────────────┐
-- │ Add prompt                                │
-- └───────────────────────────────────────────┘

local function get_path(name, info)
  info = info or ensure_repo_info()
  if info == nil then return nil end

  return vim.fs.joinpath(info.repo_dir, name)
end

local function add(base, name)
  local info = ensure_repo_info()
  if info == nil then return false end

  base = vim.trim(base or '')
  name = vim.trim(name or '')
  if base == '' or name == '' then return false end

  local path = get_path(name, info)
  if path == nil then return false end
  if vim.uv.fs_stat(path) ~= nil then
    vim.notify('Worktree path already exists: ' .. path, vim.log.levels.WARN)
    return false
  end

  vim.fn.mkdir(vim.fs.dirname(path), 'p')

  local result = run_git({ 'worktree', 'add', '-b', name, path, base }, { cwd = info.current_root })
  if result.code ~= 0 then
    notify_git_error('worktree add', result)
    return false
  end

  vim.fn.setreg('+', path)
  vim.notify('Created worktree and yanked path: ' .. path, vim.log.levels.INFO)
  return true
end

function M.add_worktree()
  local pickers = require('neocraft.features.pickers')

  pickers.worktree_bases(function(item)
    vim.schedule(function()
      vim.ui.input({
        prompt = ('Enter worktree name associated to %s:'):format(item.label or item.value),
      }, function(name)
        if name == nil then return end

        name = vim.trim(name)
        if name == '' then return end

        add(item.value, name)
      end)
    end)
  end)
end

-- ┌───────────────────────────────────────────┐
-- │ Copy files prompt                         │
-- └───────────────────────────────────────────┘

local function copy_files(files, destination)
  destination = normalize(destination)
  if destination == nil then return false end

  local copied, failed = 0, {}

  for _, file in ipairs(files or {}) do
    local source_path = normalize(type(file) == 'table' and file.path or file)
    local relative_path = type(file) == 'table' and file.relative_path or nil

    if source_path == nil or relative_path == nil or relative_path == '' then
      table.insert(failed, tostring(relative_path or source_path or '<unknown>'))
    else
      local target_path = vim.fs.joinpath(destination, relative_path)

      vim.fn.mkdir(vim.fs.dirname(target_path), 'p')

      local ok, err = vim.uv.fs_copyfile(source_path, target_path)
      if ok then
        copied = copied + 1
      else
        table.insert(failed, relative_path .. ': ' .. tostring(err))
      end
    end
  end

  if #failed > 0 then
    vim.notify('Copied ' .. copied .. ' file(s) with errors:\n' .. table.concat(failed, '\n'), vim.log.levels.ERROR)
    return false
  end

  vim.notify(('Copied %d file(s) to %s'):format(copied, destination), vim.log.levels.INFO)
  return true
end

function M.copy_files_to_worktree()
  local pickers = require('neocraft.features.pickers')

  pickers.worktree_files(function(files)
    vim.schedule(function()
      pickers.worktrees(function(item)
        local choice = vim.fn.confirm(('Overwrite %d file(s) in %s?'):format(#files, item.path), '&Yes\n&No', 2)
        if choice == 1 then copy_files(files, item.path) end
      end, {
        empty_message = 'No destination worktrees available for this project',
        exclude_current = true,
        include_main = true,
        name = 'Copy Files To Worktree',
      })
    end)
  end)
end

-- ┌───────────────────────────────────────────┐
-- │ Prune                                     │
-- └───────────────────────────────────────────┘

function M.prune_worktrees()
  local info = ensure_repo_info()
  if info == nil then return false end

  local result = run_git({ 'worktree', 'prune', '--verbose' }, { cwd = info.current_root })
  if result.code ~= 0 then
    notify_git_error('worktree prune', result)
    return false
  end

  local message = vim.trim(result.stdout or '')
  if message == '' then message = 'Pruned stale worktree metadata' end
  vim.notify(message, vim.log.levels.INFO)
  return true
end

-- ┌───────────────────────────────────────────┐
-- │ Remove prompt                             │
-- └───────────────────────────────────────────┘

local function remove(path)
  local info = ensure_repo_info()
  if info == nil then return false end

  path = normalize(path)
  if path == nil then return false end

  local result = run_git({ 'worktree', 'remove', path }, { cwd = info.current_root })
  if result.code ~= 0 then
    notify_git_error('worktree remove', result)
    return false
  end

  vim.notify('Removed worktree ' .. path, vim.log.levels.INFO)
  return true
end

function M.remove_worktree()
  local pickers = require('neocraft.features.pickers')

  pickers.worktrees(function(item)
    local choice = vim.fn.confirm(('Remove worktree %s?\n%s'):format(item.name, item.path), '&Yes\n&No', 2)
    if choice == 1 then remove(item.path) end
  end, {
    empty_message = 'No removable worktrees for this project',
    exclude_current = true,
    include_main = false,
    name = 'Remove Worktree',
  })
end

-- ┌───────────────────────────────────────────┐
-- │ Yank path prompt                          │
-- └───────────────────────────────────────────┘

local function yank_path(path)
  path = normalize(path)
  if path == nil then return false end

  vim.fn.setreg('+', path)
  vim.notify('Yanked worktree path: ' .. path, vim.log.levels.INFO)
  return true
end

function M.yank_worktree_path()
  local pickers = require('neocraft.features.pickers')

  pickers.worktrees(function(item) yank_path(item.path) end, {
    empty_message = 'No other worktrees available for this project',
    exclude_current = true,
    include_main = true,
    name = 'Yank Worktree Path',
  })
end

return M
