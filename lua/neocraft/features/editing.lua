local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Cursor and line movement                  │
-- └───────────────────────────────────────────┘

-- Return the key sequence that moves left.
function M.move_cursor_left() return '<Left>' end

-- Return the key sequence that moves down.
function M.move_cursor_down() return '<Down>' end

-- Return the key sequence that moves up.
function M.move_cursor_up() return '<Up>' end

-- Return the key sequence that moves right.
function M.move_cursor_right() return '<Right>' end

-- Return display-line or physical-line movement downward.
function M.move_by_visual_line_down() return vim.v.count == 0 and 'gj' or 'j' end

-- Return display-line or physical-line movement upward.
function M.move_by_visual_line_up() return vim.v.count == 0 and 'gk' or 'k' end

-- Move the current line up or down and reindent it.
local function move_lines(direction)
  if direction == 'down' then
    vim.cmd("execute 'move .+' . v:count1")
  else
    vim.cmd("execute 'move .-' . (v:count1 + 1)")
  end

  vim.cmd('normal! ==')
end

-- Move the current line downward.
function M.move_lines_down() move_lines('down') end

-- Move the current line upward.
function M.move_lines_up() move_lines('up') end

-- ┌───────────────────────────────────────────┐
-- │ Undo breakpoints                          │
-- └───────────────────────────────────────────┘

-- Return a comma followed by an Insert-mode undo breakpoint.
function M.comma_with_undo_breakpoint() return ',<C-g>u' end

-- Return a period followed by an Insert-mode undo breakpoint.
function M.period_with_undo_breakpoint() return '.<C-g>u' end

-- Return a semicolon followed by an Insert-mode undo breakpoint.
function M.semicolon_with_undo_breakpoint() return ';<C-g>u' end

-- ┌───────────────────────────────────────────┐
-- │ Pasting                                   │
-- └───────────────────────────────────────────┘

-- Return the key sequence that pastes without yanking the selection.
function M.paste_without_yanking_selection() return 'P' end

-- Paste the current register above the cursor line.
function M.paste_above() vim.cmd('exe "iput! " . v:register') end

-- Paste the current register below the cursor line.
function M.paste_below() vim.cmd('exe "iput " . v:register') end

-- Return the key sequence that reselects the last changed text.
function M.reselect_last_paste_or_change() return '`[v`]' end

-- ┌───────────────────────────────────────────┐
-- │ Selection                                 │
-- └───────────────────────────────────────────┘

-- Move the selected lines downward and keep them selected.
function M.move_selection_down()
  vim.cmd("'<,'>move '>+" .. vim.v.count1)
  vim.cmd('normal! gv=gv')
end

-- Move the selected lines upward and keep them selected.
function M.move_selection_up()
  vim.cmd("'<,'>move '<-" .. (vim.v.count1 + 1))
  vim.cmd('normal! gv=gv')
end

-- Return the key sequence that indents left and reselects.
function M.indent_left_keep_selection() return '<gv' end

-- Return the key sequence that indents right and reselects.
function M.indent_right_keep_selection() return '>gv' end

-- ┌───────────────────────────────────────────┐
-- │ Search                                    │
-- └───────────────────────────────────────────┘

local inline_search_count_group = Lib.augroup('inline_search_count')
local inline_search_count_ns = vim.api.nvim_create_namespace('neocraft-inline-search-count')
local search_count_delay = 500

-- Refresh the minimap search layer without redrawing lines or the scrollbar.
local function refresh_minimap_search()
  local ok, minimap = pcall(require, 'mini.map')
  if ok then minimap.refresh({}, { lines = false, scrollbar = false }) end
end

-- Perform search motion revealing folds and refreshing the minimap.
function M.search_motion_with_minimap_refresh(key)
  local prefix = vim.v.count > 0 and tostring(vim.v.count) or ''

  local ok = pcall(vim.cmd.normal, { args = { prefix .. key }, bang = true })
  if not ok then
    refresh_minimap_search()
    return
  end

  vim.cmd.normal({ args = { 'zv' }, bang = true })
  refresh_minimap_search()
  M.schedule_show_inline_search_count()
end

-- Clear the inline search count virtual text for a buffer.
local function clear_inline_search_count(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_clear_namespace(buf, inline_search_count_ns, 0, -1) end
end

-- Clear the inline search count virtual text.
function M.clear_inline_search_count() clear_inline_search_count() end

-- Show the current search result index as inline virtual text.
function M.show_inline_search_count()
  local buf = vim.api.nvim_get_current_buf()
  clear_inline_search_count(buf)
  if vim.v.hlsearch == 0 then return end

  local ok, count = pcall(vim.fn.searchcount, { recompute = 1, maxcount = 0 })
  if not ok then return end

  local total = tonumber(count.total) or 0
  if total == 0 then return end

  local current = tonumber(count.current) or 0
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))

  vim.api.nvim_buf_set_extmark(buf, inline_search_count_ns, row - 1, col, {
    virt_text = { { string.format('    󰍉  [%d/%d]', current, total), 'DiagnosticWarn' } },
    virt_text_pos = 'eol',
    hl_mode = 'combine',
  })

  vim.api.nvim_clear_autocmds({ group = inline_search_count_group, buffer = buf })

  Lib.autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertEnter', 'BufLeave' }, {
    group = inline_search_count_group,
    buffer = buf,
    once = true,
    desc = 'Clear inline search count',
    callback = function(args) clear_inline_search_count(args.buf) end,
  })
end

-- Show the inline search count after search jump scrolling has settled.
function M.schedule_show_inline_search_count()
  local buf = vim.api.nvim_get_current_buf()

  vim.defer_fn(function()
    if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_get_current_buf() ~= buf then return end
    M.show_inline_search_count()
  end, search_count_delay)
end

-- ┌───────────────────────────────────────────┐
-- │ Scrolling                                 │
-- └───────────────────────────────────────────┘

-- Classify the cursor position within the current window.
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

-- Scroll down or recenter depending on the cursor band.
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

-- Scroll up or recenter depending on the cursor band.
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

-- Scroll the viewport left by one column.
function M.scroll_view_left() vim.cmd('normal! zh') end

-- Scroll the viewport right by one column.
function M.scroll_view_right() vim.cmd('normal! zl') end

-- Scroll the viewport left by half a screen.
function M.scroll_view_half_left() vim.cmd('normal! zH') end

-- Scroll the viewport right by half a screen.
function M.scroll_view_half_right() vim.cmd('normal! zL') end

local mouse_scroll_tick = 0

-- Return a mouse scroll key while temporarily disabling scroll animation.
function M.mouse_scroll_without_animation(key)
  mouse_scroll_tick = mouse_scroll_tick + 1
  local tick = mouse_scroll_tick

  vim.g.neocraft_mouse_scrolling = true
  vim.defer_fn(function()
    if tick == mouse_scroll_tick then vim.g.neocraft_mouse_scrolling = false end
  end, 80)

  return key
end

-- ┌───────────────────────────────────────────┐
-- │ Diagnostics and code                      │
-- └───────────────────────────────────────────┘

-- Jump to the next or previous diagnostic with an optional severity.
function M.goto_diagnostic(next, severity)
  local count = next and 1 or -1
  local level = severity and vim.diagnostic.severity[severity] or nil

  vim.diagnostic.jump({ count = count, severity = level })
end

-- Show diagnostics for the current line.
function M.line_diagnostics() vim.diagnostic.open_float() end

-- Return the built-in tag jump key sequence.
function M.go_to_definition_or_tag() return vim.keycode('<C-]>') end

return M
