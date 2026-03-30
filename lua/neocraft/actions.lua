local M = {}

local function restart(keep_session)
  if keep_session == false then
    local sessions = require('neocraft.core.sessions')
    sessions.discard_once()
    sessions.delete_current()
  end

  vim.defer_fn(function() vim.cmd('confirm restart') end, 500)
end

function M.restart_neovim()
  local choice = vim.fn.confirm('Keep session for this project?', '&Yes\n&No', 1)
  if choice == 0 then return end

  restart(choice == 1)
end

local function has_modified_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then return true end
  end

  return false
end

function M.previous_buffer() vim.cmd.bprevious() end

function M.next_buffer() vim.cmd.bnext() end

function M.new_buffer() vim.cmd('enew | startinsert') end

function M.delete_buffer() require('mini.bufremove').delete(0, false) end

function M.save() vim.cmd('silent! update | redraw') end

local function input_key(key) vim.api.nvim_input(vim.keycode(key)) end

function M.save_and_normal_mode()
  local mode = vim.fn.mode(1)

  if mode:find('^i') or mode:find('^R') then
    vim.cmd.stopinsert()
  elseif mode:find('^[vV\22sS]') then
    input_key('<Esc>')
  end

  M.save()
end

function M.exit_terminal_mode() input_key('<C-\\><C-n>') end

function M.clear_on_escape()
  vim.cmd.nohlsearch()
  require('mini.notify').clear()
end

function M.show_action_picker() require('neocraft.pickers').actions() end

function M.move_left() input_key('<Left>') end

function M.move_down() input_key('<Down>') end

function M.move_up() input_key('<Up>') end

function M.move_right() input_key('<Right>') end

local function move_lines(direction)
  if direction == 'down' then
    vim.cmd("execute 'move .+' . v:count1")
  else
    vim.cmd("execute 'move .-' . (v:count1 + 1)")
  end

  vim.cmd('normal! ==')
end

function M.move_lines_down() move_lines('down') end

function M.move_lines_up() move_lines('up') end

local function cursor_band()
  local row = vim.fn.winline()
  local height = vim.api.nvim_win_get_height(0)
  local mid_lo, mid_hi = math.floor(height / 2), math.ceil(height / 2)

  if row == mid_lo or row == mid_hi then
    return 'middle'
  elseif row < (height / 2) then
    return 'top'
  else
    return 'bottom'
  end
end

function M.halfpage_down()
  local band = cursor_band()
  if band == 'middle' then
    local count = vim.v.count > 0 and tostring(vim.v.count) or ''
    return count .. '<C-d>'
  elseif band == 'top' then
    return 'M'
  else
    return 'Lzz'
  end
end

function M.halfpage_up()
  local band = cursor_band()
  if band == 'middle' then
    local count = vim.v.count > 0 and tostring(vim.v.count) or ''
    return count .. '<C-u>'
  elseif band == 'top' then
    return 'Hzz'
  else
    return 'M'
  end
end

function M.scroll_view_left() vim.cmd('normal! zh') end

function M.scroll_view_right() vim.cmd('normal! zl') end

function M.scroll_view_half_left() vim.cmd('normal! zH') end

function M.scroll_view_half_right() vim.cmd('normal! zL') end

local function navigate(direction, cli_direction)
  local cur_win = vim.api.nvim_get_current_win()
  vim.api.nvim_cmd({ cmd = 'wincmd', args = { direction } }, {})
  local new_win = vim.api.nvim_get_current_win()

  if new_win == cur_win and vim.env.WEZTERM_PANE then
    vim.system({ 'wezterm', 'cli', 'activate-pane-direction', cli_direction }, { detach = true })
  end
end

function M.focus_left() navigate('h', 'Left') end

function M.focus_down() navigate('j', 'Down') end

function M.focus_up() navigate('k', 'Up') end

function M.focus_right() navigate('l', 'Right') end

function M.resize_width(delta) vim.cmd('vertical resize ' .. (delta > 0 and '+' or '-') .. math.abs(delta)) end

function M.resize_height(delta) vim.cmd('resize ' .. (delta > 0 and '+' or '-') .. math.abs(delta)) end

function M.resize_left() M.resize_width(-vim.v.count1) end

function M.resize_down() M.resize_height(-vim.v.count1) end

function M.resize_up() M.resize_height(vim.v.count1) end

function M.resize_right() M.resize_width(vim.v.count1) end

local function reset_maximized_flags()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    vim.w[win].maximized = false
  end
end

function M.maximize(enable)
  if enable then
    reset_maximized_flags()
    vim.w.maximized = true
    vim.cmd.wincmd('|')
    vim.cmd.wincmd('_')
    return
  end

  vim.cmd.wincmd('=')

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    vim.w[win].maximized = false

    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == 'quickfix' then pcall(vim.api.nvim_win_set_height, win, 10) end
  end
end

function M.toggle_maximized() M.maximize(not vim.w.maximized) end

function M.buffer_delete_command() vim.cmd('NeocraftBufferDelete') end

function M.buffer_wipeout_command() vim.cmd('NeocraftBufferWipeout') end

function M.quit_neovim()
  local msg = has_modified_buffers() and 'You have unsaved changes! Quit anyway?' or 'Quit Neovim?'
  local choice = vim.fn.confirm(msg, '&Yes\n&No\n&Cancel', 2)
  if choice == 1 then vim.api.nvim_cmd({ cmd = 'qall', bang = true }, {}) end
end

return M
