-- Configure mini.files and expose Neocraft file explorer helpers.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local show_dotfiles = true

local root = require('neocraft.core.root')

-- Get the current file system entry from the mini.files explorer.
local function current_fs_entry() return require('mini.files').get_fs_entry() end

-- Get the absolute path of the current file explorer entry.
local function current_entry_path()
  local entry = current_fs_entry()
  return entry and entry.path or nil
end

-- Get the relative path of the current file explorer entry.
local function current_entry_relative_path()
  local path = current_entry_path()
  if path == nil then return nil end

  local project_root = root.get()
  if project_root == nil then return path end

  return vim.fs.relpath(project_root, path) or path
end

-- Yank the given value to the system clipboard and show a notification with the provided message.
local function yank_to_clipboard(value, message)
  if value == nil or value == '' then
    vim.notify('No path selected in file explorer', vim.log.levels.WARN)
    return
  end

  vim.fn.setreg('+', value)
  vim.api.nvim_echo({ { message, 'Normal' } }, false, {})
end

-- Copy the relative path of the current file explorer entry to the clipboard.
local function copy_entry_relative_path()
  yank_to_clipboard(current_entry_relative_path(), 'Yanked relative path to clipboard')
end

-- Copy the absolute path of the current file explorer entry to the clipboard.
local function copy_entry_absolute_path() yank_to_clipboard(current_entry_path(), 'Yanked absolute path to clipboard') end

-- Open the current file explorer entry with the system's default handler.
local function open_entry_with_system()
  local path = current_entry_path()
  if path == nil then
    vim.notify('No path selected in file explorer', vim.log.levels.WARN)
    return
  end

  vim.ui.open(path)
end

-- Toggle visibility of dotfiles in the file explorer and refresh the view.
local function toggle_dotfiles()
  show_dotfiles = not show_dotfiles

  local filter = show_dotfiles and function() return true end
    or function(fs_entry) return not vim.startswith(fs_entry.name, '.') end

  require('mini.files').refresh({ content = { filter = filter } })
end

-- Open the current file explorer entry in a split based on the given direction.
local function split_entry(direction)
  local entry = current_fs_entry()
  if entry == nil then
    vim.notify('No path selected in file explorer', vim.log.levels.WARN)
    return
  end

  if entry.fs_type ~= 'file' then
    vim.notify('Split open works on files only', vim.log.levels.INFO)
    return
  end

  local mini_files = require('mini.files')
  local state = mini_files.get_explorer_state()
  local target_window = state and state.target_window or nil
  if not (target_window and vim.api.nvim_win_is_valid(target_window)) then return end

  local new_target_window
  vim.api.nvim_win_call(target_window, function()
    vim.cmd(direction .. ' split')
    new_target_window = vim.api.nvim_get_current_win()
  end)

  if new_target_window == nil then return end

  mini_files.set_target_window(new_target_window)
  mini_files.go_in({ close_on_file = false })
end

-- Open the current file explorer entry in a new tab.
local function tab_entry()
  local entry = current_fs_entry()
  if entry == nil then
    vim.notify('No path selected in file explorer', vim.log.levels.WARN)
    return
  end

  if entry.fs_type ~= 'file' then
    vim.notify('Tab open works on files only', vim.log.levels.INFO)
    return
  end

  local mini_files = require('mini.files')
  local state = mini_files.get_explorer_state()
  local target_window = state and state.target_window or nil
  if not (target_window and vim.api.nvim_win_is_valid(target_window)) then return end

  local new_tabpage
  local new_target_window
  mini_files.close()
  vim.api.nvim_win_call(target_window, function()
    vim.cmd.tabedit(vim.fn.fnameescape(entry.path))
    new_tabpage = vim.api.nvim_get_current_tabpage()
    new_target_window = vim.api.nvim_get_current_win()
  end)

  if new_tabpage == nil or new_target_window == nil then return end

  vim.api.nvim_set_current_tabpage(new_tabpage)
  vim.api.nvim_set_current_win(new_target_window)
  mini_files.open(entry.path, false)
  mini_files.reveal_cwd()
end

-- Set up buffer-local mappings for mini.files explorer buffers.
local function map_files_buffer(buf_id)
  vim.keymap.set('n', '<C-s>', function() split_entry('belowright horizontal') end, {
    buffer = buf_id,
    desc = 'Open file in horizontal split',
  })
  vim.keymap.set('n', '<C-v>', function() split_entry('belowright vertical') end, {
    buffer = buf_id,
    desc = 'Open file in vertical split',
  })
  vim.keymap.set('n', '<C-t>', tab_entry, {
    buffer = buf_id,
    desc = 'Open file in new tab',
  })
  vim.keymap.set('n', 'g.', toggle_dotfiles, {
    buffer = buf_id,
    desc = 'Toggle hidden files',
  })
  vim.keymap.set('n', 'gy', copy_entry_relative_path, {
    buffer = buf_id,
    desc = 'Copy relative path',
  })
  vim.keymap.set('n', 'gY', copy_entry_absolute_path, {
    buffer = buf_id,
    desc = 'Copy absolute path',
  })
  vim.keymap.set('n', 'gx', open_entry_with_system, {
    buffer = buf_id,
    desc = 'Open with system handler',
  })
end

-- ┌───────────────────────────────────────────┐
-- │ Setup Mini Files & local mappings         │
-- └───────────────────────────────────────────┘

Lib.now(function()
  require('mini.files').setup({
    windows = {
      preview = false,
      width_nofocus = 30,
      width_focus = 30,
      width_preview = 30,
    },
    mappings = {
      go_in_plus = '<CR>',
      close = '<Esc>',
    },
    options = {
      use_as_default_explorer = true,
    },
  })

  Lib.autocmd('User', {
    group = Lib.augroup('mini_files'),
    pattern = 'MiniFilesBufferCreate',
    desc = 'Add explorer-local mappings for mini.files',
    callback = function(args) map_files_buffer(args.data.buf_id) end,
  })
end)

return M
