local M = {}

local function resolve_buf(buf) return (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf end

local function has_file_context(buf)
  buf = resolve_buf(buf)

  return vim.bo[buf].buftype == '' and vim.api.nvim_buf_get_name(buf) ~= ''
end

local function notify_missing_file(action) vim.notify('No file context for Git ' .. action, vim.log.levels.WARN) end

local function git(cmd) vim.cmd('Git ' .. cmd) end

local function save_buffer(buf)
  buf = resolve_buf(buf)

  return vim.api.nvim_buf_call(buf, function() return pcall(vim.cmd, 'silent update') end)
end

function M.add_file()
  if not has_file_context() then
    notify_missing_file('add')
    return
  end

  local ok = save_buffer(0)
  if not ok then return end

  git('add -- %')
end

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

  git('add -A')
end

function M.blame()
  if not has_file_context() then
    notify_missing_file('blame')
    return
  end

  git('blame -- %')
end

function M.commit() git('commit') end

function M.commit_amend() git('commit --amend') end

-- Show contextual git-related details based on file type and what is currently selected or under the cursor:
-- * normal file: show line diff history
-- * diff patch:  show state of file belonging to the version under cursor
-- * commit hash: show the commit associated to that hash
function M.details() require('mini.git').show_at_cursor({ split = 'auto' }) end

function M.log_repo() git('log --oneline --topo-order') end

function M.log_buffer()
  if not has_file_context() then
    notify_missing_file('log')
    return
  end

  git('log -p --follow -- %')
end

function M.status() git('status') end

Lib.later(
  function()
    require('mini.diff').setup({
      view = {
        style = 'sign',
        signs = {
          add = '▎',
          change = '▎',
          delete = '▎',
        },
      },
    })
  end
)

function M.toggle_overlay() require('mini.diff').toggle_overlay(0) end

-- Lib.later(function() require('mini.git').setup({ command = { split = 'tab' } }) end)
Lib.later(function() require('mini.git').setup() end)

return M

