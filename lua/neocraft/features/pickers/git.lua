local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local function git_branch_preview(buf_id, item)
  if type(item) ~= 'table' then return end

  local lines = {
    'Branch: ' .. (item.branch or ''),
    'Sha: ' .. (item.sha or ''),
    '',
    item.subject or '',
  }

  if item.ref then table.insert(lines, 2, 'Ref: ' .. item.ref) end

  vim.bo[buf_id].filetype = 'text'
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
end

---@param buf_id integer
---@param item? neocraft.git.BaseItem
local function worktree_base_preview(buf_id, item)
  if type(item) ~= 'table' then return end

  local lines = {
    'Kind: ' .. (item.kind or 'unknown'),
    'Value: ' .. (item.value or ''),
    '',
    item.text or '',
  }

  if item.kind == 'custom' then
    lines = {
      'Kind: custom',
      '',
      'Pick this item to type any commit-ish manually.',
    }
  end

  vim.bo[buf_id].filetype = 'text'
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
end

---@param buf_id integer
---@param item? neocraft.git.WorktreeItem
local function worktree_preview(buf_id, item)
  if type(item) ~= 'table' then return end

  local lines = {
    'Name: ' .. (item.name or ''),
    'Path: ' .. (item.path or ''),
    'Branch: ' .. (item.branch or ''),
    'HEAD: ' .. (item.head or ''),
    'Main repo: ' .. tostring(item.is_main == true),
    'Current: ' .. tostring(item.is_current == true),
  }

  if item.locked then table.insert(lines, 'Locked: ' .. tostring(item.locked)) end
  if item.prunable then table.insert(lines, 'Prunable: ' .. tostring(item.prunable)) end

  vim.bo[buf_id].filetype = 'text'
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
end

local function read_preview_chunk(path)
  local fd = vim.uv.fs_open(path, 'r', 438)
  if fd == nil then return nil end

  local chunk = vim.uv.fs_read(fd, 4096, 0)
  vim.uv.fs_close(fd)

  return chunk
end

---@param buf_id integer
---@param item? neocraft.git.FileItem
local function worktree_file_preview(buf_id, item)
  if type(item) ~= 'table' then return end

  local lines = {
    'Path: ' .. (item.relative_path or ''),
    'Absolute: ' .. (item.path or ''),
  }

  local stat = item.path and vim.uv.fs_stat(item.path) or nil
  if stat and stat.size then table.insert(lines, 'Size: ' .. stat.size .. ' bytes') end

  local chunk = item.path and read_preview_chunk(item.path) or nil
  if chunk == nil then
    table.insert(lines, '')
    table.insert(lines, 'Preview unavailable')
  elseif chunk:find('\0', 1, true) then
    table.insert(lines, '')
    table.insert(lines, 'Binary file preview unavailable')
  else
    table.insert(lines, '')
    table.insert(lines, 'Preview:')

    local preview = vim.split(chunk, '\n', { plain = true })
    for i = 1, math.min(#preview, 80) do
      table.insert(lines, preview[i])
    end
  end

  vim.bo[buf_id].filetype = 'text'
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

function M.git_local_branches(on_choice)
  local git = require('neocraft.features.git')
  local items, err = git.local_branch_items()

  if not items then
    vim.notify(err or 'Could not load local branches', vim.log.levels.WARN)
    return
  end
  if #items == 0 then
    vim.notify('No deletable local branches available', vim.log.levels.INFO)
    return
  end

  return require('mini.pick').start({
    source = {
      items = items,
      name = 'Local Branches',
      preview = git_branch_preview,
      choose = function(item)
        if type(item) ~= 'table' or type(on_choice) ~= 'function' then return end
        vim.schedule(function() on_choice(item) end)
      end,
    },
  })
end

function M.git_remote_branches(on_choice)
  local git = require('neocraft.features.git')
  local items, err = git.remote_branch_items()

  if not items then
    vim.notify(err or 'Could not load remote branches', vim.log.levels.WARN)
    return
  end
  if #items == 0 then
    vim.notify('No deletable remote branches available', vim.log.levels.INFO)
    return
  end

  return require('mini.pick').start({
    source = {
      items = items,
      name = 'Remote Branches',
      preview = git_branch_preview,
      choose = function(item)
        if type(item) ~= 'table' or type(on_choice) ~= 'function' then return end
        vim.schedule(function() on_choice(item) end)
      end,
    },
  })
end

---@param on_choice fun(item: neocraft.git.BaseItem)
function M.worktree_bases(on_choice)
  local worktrees = require('neocraft.features.git.worktrees')
  local items, info_or_err = worktrees.base_items()

  if not items then
    local message = type(info_or_err) == 'string' and info_or_err or 'Could not load worktree bases'
    vim.notify(message, vim.log.levels.WARN)
    return
  end

  return require('mini.pick').start({
    source = {
      items = items,
      name = 'Worktree Bases',
      preview = worktree_base_preview,
      choose = function(item)
        if type(item) ~= 'table' or type(on_choice) ~= 'function' then return end

        if item.kind == 'custom' then
          vim.schedule(function()
            vim.ui.input({ prompt = 'Custom base commit-ish: ' }, function(input)
              if input == nil then return end

              local value = vim.trim(input)
              if value == '' then return end

              on_choice({ kind = 'custom', label = value, text = value, value = value })
            end)
          end)
          return
        end

        vim.schedule(function() on_choice(item) end)
      end,
    },
  })
end

---@class neocraft.pickers.WorktreesOpts
---@field empty_message? string
---@field exclude_current? boolean
---@field include_main? boolean
---@field name? string

---@param on_choice fun(item: neocraft.git.WorktreeItem)
---@param opts? neocraft.pickers.WorktreesOpts
function M.worktrees(on_choice, opts)
  opts = vim.tbl_extend('force', {
    empty_message = 'No worktrees found for this project',
    exclude_current = false,
    include_main = true,
    name = 'Worktrees',
  }, opts or {})

  local worktrees = require('neocraft.features.git.worktrees')
  local items, err = worktrees.list()

  if not items then
    vim.notify(err --[[@as string?]] or 'Could not load worktrees', vim.log.levels.WARN)
    return
  end

  items = vim.tbl_filter(function(item)
    if not opts.include_main and item.is_main then return false end
    if opts.exclude_current and item.is_current then return false end
    return true
  end, items)

  if #items == 0 then
    vim.notify(opts.empty_message, vim.log.levels.INFO)
    return
  end

  return require('mini.pick').start({
    source = {
      items = items,
      name = opts.name,
      preview = worktree_preview,
      choose = function(item)
        if type(item) ~= 'table' or type(on_choice) ~= 'function' then return end
        vim.schedule(function() on_choice(item) end)
      end,
    },
  })
end

---@param on_choice fun(items: neocraft.git.FileItem[])
function M.worktree_files(on_choice)
  local worktrees = require('neocraft.features.git.worktrees')
  local items, info_or_err = worktrees.project_file_items()

  if not items then
    local message = type(info_or_err) == 'string' and info_or_err or 'Could not load project files'
    vim.notify(message, vim.log.levels.WARN)
    return
  end
  if #items == 0 then
    vim.notify('No files available to copy from this project', vim.log.levels.INFO)
    return
  end

  return require('mini.pick').start({
    source = {
      items = items,
      name = 'Worktree Files | <C-x> = select item | <M-CR> = confirm selected',
      preview = worktree_file_preview,
      choose = function(item)
        if type(item) ~= 'table' or type(on_choice) ~= 'function' then return end
        vim.schedule(function() on_choice({ item }) end)
      end,
      choose_marked = function(items_marked)
        if type(on_choice) ~= 'function' or #items_marked == 0 then return end
        vim.schedule(function() on_choice(items_marked) end)
      end,
    },
  })
end

return M
