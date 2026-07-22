local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Buffers                                   │
-- └───────────────────────────────────────────┘

-- Open a new empty buffer and enter Insert mode.
function M.new_buffer() vim.cmd('enew | startinsert') end

-- Switch to the alternate buffer.
function M.alternate_buffer() vim.cmd.edit('#') end

-- Switch to the next listed buffer.
function M.next_buffer() vim.cmd.bnext() end

-- Switch to the previous listed buffer.
function M.previous_buffer() vim.cmd.bprevious() end

-- Delete all listed buffers except the current one.
function M.delete_other_buffers()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and b ~= vim.api.nvim_get_current_buf() then require('mini.bufremove').delete(b, false) end
  end
end

-- Hard reload the current buffer and restart any attached LSP clients.
function M.reload_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local view = vim.fn.winsaveview()

  -- If this is a hard reload and buffer has unsaved changes, confirm first.
  if vim.bo[bufnr].modified then
    local choice = vim.fn.confirm(
      'Discard unsaved changes in this buffer?',
      '&Yes\n&No',
      2 -- default to "No"
    )
    if choice ~= 1 then
      vim.fn.winrestview(view)
      return false
    end
  end

  -- Stop LSP clients on this buffer, but leave Copilot alone (it doesn't like being hard-stopped).
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    local name = (c.name or ''):lower()
    if name ~= 'copilot' and name ~= 'copilot_ls' then
      c:stop(true) -- force stop; they'll reattach on BufRead/FileType via your setup
    end
  end

  -- Re-read the file (hard = discard changes).
  vim.cmd.edit({ bang = true })

  vim.fn.winrestview(view)

  vim.api.nvim_echo({ { 'Reloaded buffer "' .. vim.api.nvim_buf_get_name(bufnr) .. '"', 'Normal' } }, false, {})

  return true
end

-- Prompt for and set the current buffer filetype.
function M.set_buffer_filetype()
  vim.ui.input({
    prompt = 'Set filetype (e.g. jsonc, lua, markdown): ',
    default = vim.bo.filetype,
  }, function(ft)
    if not ft or ft == '' then return end
    vim.bo.filetype = ft
    vim.api.nvim_echo({ { 'Buffer filetype set to "' .. ft .. '"', 'Normal' } }, false, {})
  end)
end

-- Yank the current buffer path relative to cwd to the clipboard.
function M.yank_relative_path()
  vim.fn.setreg('+', vim.fn.expand('%'))
  vim.api.nvim_echo({ { 'Yanked relative path to clipboard', 'Normal' } }, false, {})
end

-- Yank the current buffer absolute path to the clipboard.
function M.yank_absolute_path()
  vim.fn.setreg('+', vim.fn.expand('%:p'))
  vim.api.nvim_echo({ { 'Yanked absolute path to clipboard', 'Normal' } }, false, {})
end

-- Yank the entire buffer without moving the cursor.
function M.copy_buffer_content() vim.cmd('silent keepjumps %yank') end

-- Save the current buffer, prompting for a path when the buffer is unnamed.
function M.save()
  local buf = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)

  if name ~= '' then
    vim.cmd('silent! update | redraw')
    return
  end

  vim.ui.input({
    prompt = 'Save as: ',
    default = (vim.uv.cwd() or vim.fn.getcwd()) .. '/',
  }, function(path)
    if not path or path == '' or not vim.api.nvim_buf_is_valid(buf) then return end

    path = vim.fn.fnamemodify(vim.fn.expand(path), ':p')
    local dir = vim.fs.dirname(path)
    if dir and dir ~= '' then pcall(vim.fn.mkdir, dir, 'p') end

    local ok, err = pcall(function()
      vim.api.nvim_buf_set_name(buf, path)
      vim.api.nvim_buf_call(buf, function() vim.cmd('write | redraw') end)
    end)

    if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
  end)
end

-- Save without running format-on-save hooks.
function M.save_without_formatting()
  local mode = vim.fn.mode(1)

  if mode:find('^i') or mode:find('^R') then
    vim.cmd.stopinsert()
  elseif mode:find('^[vV\22sS]') then
    vim.api.nvim_input(vim.keycode('<Esc>'))
  end

  vim.cmd('silent! noautocmd update | redraw')
end

-- Leave Insert/Visual mode and save the current buffer.
function M.save_and_normal_mode()
  local mode = vim.fn.mode(1)

  if mode:find('^i') or mode:find('^R') then
    vim.cmd.stopinsert()
  elseif mode:find('^[vV\22sS]') then
    vim.api.nvim_input(vim.keycode('<Esc>'))
  end

  M.save()
end

-- Delete the current buffer without closing the window.
function M.delete_buffer() require('mini.bufremove').delete(0, false) end

-- ┌───────────────────────────────────────────┐
-- │ Window                                    │
-- └───────────────────────────────────────────┘

-- Open a horizontal split below the current window.
function M.split_below() vim.cmd.split() end

-- Open a vertical split to the right of the current window.
function M.split_right() vim.cmd.vsplit() end

-- Close the current window, or the current tab when it only has one regular window.
function M.close_window_or_tab()
  local function notify_close_error(err) vim.notify(tostring(err), vim.log.levels.WARN) end

  if vim.fn.winnr('$') > 1 then
    local ok, err = pcall(vim.cmd.close)
    if not ok then notify_close_error(err) end
  elseif vim.fn.tabpagenr('$') > 1 then
    local ok, err = pcall(vim.cmd.tabclose)
    if not ok then notify_close_error(err) end
  else
    vim.notify('Cannot close the last window', vim.log.levels.WARN)
  end
end

-- Focus a neighboring window, falling back to herdr/wezterm pane navigation.
local function navigate(direction, cli_direction)
  local cur_win = vim.api.nvim_get_current_win()
  vim.api.nvim_cmd({ cmd = 'wincmd', args = { direction } }, {})
  local new_win = vim.api.nvim_get_current_win()

  -- If window didn't change, we're at the edge.
  if new_win == cur_win and vim.env.HERDR_PANE_ID and vim.env.HERDR_PANE_ID ~= '' then
    local herdr = vim.env.HERDR_BIN_PATH
    if herdr == nil or herdr == '' then herdr = 'herdr' end
    vim.fn.system({ herdr, 'pane', 'focus', '--direction', cli_direction:lower(), '--current' })
  elseif new_win == cur_win and vim.env.WEZTERM_PANE then
    vim.system({ 'wezterm', 'cli', 'activate-pane-direction', cli_direction }, { detach = true })
  end
end

-- Focus the window or terminal pane to the left.
function M.focus_left() navigate('h', 'Left') end

-- Focus the window or terminal pane below.
function M.focus_down() navigate('j', 'Down') end

-- Focus the window or terminal pane above.
function M.focus_up() navigate('k', 'Up') end

-- Focus the window or terminal pane to the right.
function M.focus_right() navigate('l', 'Right') end

-- Resize the current window horizontally by a delta.
local function resize_width(delta) vim.cmd('vertical resize ' .. (delta > 0 and '+' or '-') .. math.abs(delta)) end

-- Resize the current window vertically by a delta.
local function resize_height(delta) vim.cmd('resize ' .. (delta > 0 and '+' or '-') .. math.abs(delta)) end

-- Decrease the current window width by the count.
function M.resize_left() resize_width(-vim.v.count1) end

-- Decrease the current window height by the count.
function M.resize_down() resize_height(-vim.v.count1) end

-- Increase the current window height by the count.
function M.resize_up() resize_height(vim.v.count1) end

-- Increase the current window width by the count.
function M.resize_right() resize_width(vim.v.count1) end

-- Return Neovim's metadata for a window.
local function window_info(win)
  local ok, info = pcall(vim.fn.getwininfo, win)
  if not ok or info[1] == nil then return nil end

  return info[1]
end

-- Check whether a window is backed by a quickfix or location list.
local function is_list_window(win)
  local info = window_info(win)
  return info ~= nil and (info.quickfix == 1 or info.loclist == 1)
end

-- Return the Diffview view for the current tab, when present.
local function current_diffview()
  local ok, lib = pcall(require, 'diffview.lib')
  if not ok then return nil end

  return lib.get_current_view()
end

-- Collect open Diffview panels associated with a view.
local function diffview_panels(view)
  if type(view) ~= 'table' then return {} end

  return {
    view.panel,
    view.panel and view.panel.option_panel,
    view.commit_log_panel,
  }
end

-- Check whether a Diffview panel owns a valid window.
local function is_open_diffview_panel(panel)
  return type(panel) == 'table' and type(panel.winid) == 'number' and vim.api.nvim_win_is_valid(panel.winid)
end

-- Restore Diffview panel dimensions using Diffview's own layout state.
local function resize_diffview_panels(view)
  for _, panel in ipairs(diffview_panels(view)) do
    if is_open_diffview_panel(panel) and type(panel.resize) == 'function' then pcall(panel.resize, panel) end
  end
end

-- Clear maximized-window markers in the current tab.
local function reset_maximized_flags()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    vim.w[win].maximized = false
  end
end

-- Maximize or restore the current window layout.
local function maximize(enable)
  local view = current_diffview()

  if enable then
    reset_maximized_flags()
    vim.w.maximized = true
    vim.cmd.wincmd('|')
    vim.cmd.wincmd('_')
    return
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    vim.w[win].maximized = false
    if is_list_window(win) then pcall(vim.api.nvim_win_set_height, win, 10) end
  end

  resize_diffview_panels(view)

  vim.schedule(function() vim.cmd.wincmd('=') end)
end

-- Toggle whether the current window is maximized.
function M.toggle_maximized() maximize(not vim.w.maximized) end

-- ┌───────────────────────────────────────────┐
-- │ Tabs                                      │
-- └───────────────────────────────────────────┘

-- Open a new tab page.
function M.new_tab() vim.cmd.tabnew() end

-- Switch to the next tab page.
function M.next_tab() vim.cmd.tabnext() end

-- Switch to the previous tab page.
function M.previous_tab() vim.cmd.tabprevious() end

return M
