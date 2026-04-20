-- Pending Git file navigation.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local root = require('neocraft.core.root')
local util = require('neocraft.features.git.util')

-- Show a path relative to the Git root when possible.
local function rel_to_root(path, git_root_path) return vim.fs.relpath(git_root_path, path) or vim.fs.basename(path) end

-- Return the listed buffer already showing a path, if any.
local function existing_buffer(path)
  local normalized = root.realpath(path)
  if normalized == nil then return nil end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and root.bufpath(buf) == normalized then return buf end
  end
end

-- Open a file path in the current window, reporting whether it created a buffer.
local function open_file(path)
  local is_new_buffer = existing_buffer(path) == nil
  vim.cmd('edit ' .. vim.fn.fnameescape(path))

  return is_new_buffer, vim.api.nvim_get_current_buf()
end

-- Jump to the first hunk once mini.diff has data for a newly opened buffer.
local function jump_first_hunk_when_ready(buf)
  local done = false
  local autocmd

  local function jump()
    if done then return true end
    if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_get_current_buf() ~= buf then
      done = true
      return true
    end

    local ok, mini_diff = pcall(require, 'mini.diff')
    if not ok then
      done = true
      return true
    end

    local data = mini_diff.get_buf_data(buf)
    if data == nil or data.hunks == nil or #data.hunks == 0 then return false end

    require('neocraft.features.git.hunks').goto_hunk('first')
    done = true
    if autocmd then pcall(vim.api.nvim_del_autocmd, autocmd) end
    return true
  end

  if jump() then return end

  local first_hunk_group = Lib.augroup('git_pending_first_hunk')

  autocmd = Lib.autocmd('User', {
    group = first_hunk_group,
    pattern = 'MiniDiffUpdated',
    desc = 'Jump pending Git file to its first hunk',
    callback = function(args)
      if args.buf ~= buf then return end
      jump()
    end,
  })

  local attempts = 0
  local function retry()
    attempts = attempts + 1
    if jump() or attempts >= 20 then
      done = true
      pcall(vim.api.nvim_del_autocmd, autocmd)
      return
    end

    vim.defer_fn(retry, 50)
  end

  vim.defer_fn(retry, 50)
end

-- Find the index of a value inside a list.
local function index_of(list, value)
  for i, item in ipairs(list) do
    if item == value then return i end
  end
end

-- List pending file paths for staged or unstaged changes.
local function pending_files(repo_root, staged)
  local result = util.run_system({ 'git', 'status', '--porcelain=v1', '-z', '--untracked-files=all' }, {
    cwd = repo_root,
    text = true,
  })
  if result.code ~= 0 then return {}, {} end

  local tokens = {}
  for token in (result.stdout or ''):gmatch('([^%z]+)') do
    table.insert(tokens, token)
  end

  local files = {}
  local seen = {}
  local is_new = {}
  local i = 1

  while i <= #tokens do
    local head = tokens[i]
    local xy = head:sub(1, 2)
    local x = xy:sub(1, 1)
    local y = xy:sub(2, 2)
    local path = head:sub(4)

    if x == 'R' or x == 'C' then
      i = i + 1
      path = tokens[i]
    end

    local include
    if staged then
      include = x ~= ' ' and x ~= 'D' and xy ~= '??'
    else
      include = xy == '??' or y ~= ' '
      if y == 'D' then include = false end
    end

    if include and path and path ~= '' then
      local absolute_path = vim.fs.normalize(vim.fs.joinpath(repo_root, path))
      local stat = vim.uv.fs_stat(absolute_path)

      if stat and stat.type == 'file' and not seen[absolute_path] then
        seen[absolute_path] = true
        if not staged and xy == '??' then is_new[absolute_path] = true end
        table.insert(files, absolute_path)
      end
    end

    i = i + 1
  end

  table.sort(files, function(a, b) return a:lower() < b:lower() end)

  return files, is_new
end

-- Jump to the next or previous pending file and show its position.
local function jump_pending_file(delta, staged)
  local repo_root = util.git_root_or_warn(0)
  if repo_root == nil then return end

  local files, is_new = pending_files(repo_root, staged)
  if #files == 0 then
    local message = staged and 'No staged files' or 'No untracked or unstaged files'
    vim.notify(message, vim.log.levels.INFO)
    return
  end

  local current_path = root.bufpath(0)
  local idx = current_path and index_of(files, current_path) or nil
  local target = idx == nil and (delta > 0 and 1 or #files) or ((idx - 1 + delta) % #files) + 1
  local path = files[target]

  local is_new_buffer, bufnr = open_file(path)
  if is_new_buffer then jump_first_hunk_when_ready(bufnr) end

  local tag = staged and '(STAGED)' or (is_new[path] and '(NEW)' or '(CHANGED)')
  local message = ('[%d/%d] %s %s'):format(target, #files, rel_to_root(path, repo_root), tag)
  vim.api.nvim_echo({ { message, 'Normal' } }, false, {})
end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Jump to the next pending file.
function M.next_pending_file(staged) jump_pending_file(1, staged) end

-- Jump to the previous pending file.
function M.prev_pending_file(staged) jump_pending_file(-1, staged) end

return M
