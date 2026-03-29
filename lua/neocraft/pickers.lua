local M = {}

local function mini_api() return require('neocraft.plugins.mini') end

-- ┌───────────────────────────────────────────┐
-- │ cword custom picker                       │
-- └───────────────────────────────────────────┘

function M.grep_cword(buf, opts)
  local word = vim.fn.expand('<cword>')
  if word == '' then return mini_api().grep_live(buf, opts) end

  local pat = '\\V\\<' .. vim.fn.escape(word, '\\') .. '\\>'
  vim.fn.setreg('/', pat)
  vim.opt.hlsearch = true

  opts = vim.tbl_extend('force', { buf = buf }, opts or {})
  return mini_api().pick_builtin('grep', { pattern = word }, opts)
end

-- ┌───────────────────────────────────────────┐
-- │ autocmd custom picker                     │
-- └───────────────────────────────────────────┘

local function autocmd_pattern(autocmd)
  if autocmd.pattern and autocmd.pattern ~= '' then return autocmd.pattern end
  if autocmd.buffer and autocmd.buffer ~= 0 then return 'buffer:' .. autocmd.buffer end
  return '*'
end

local function autocmd_callback_location(callback)
  if type(callback) ~= 'function' then return nil end

  local info = debug.getinfo(callback, 'S')
  if not info or type(info.source) ~= 'string' or info.source:sub(1, 1) ~= '@' then return nil, info end

  return {
    path = info.source:sub(2),
    start = info.linedefined,
    finish = info.lastlinedefined,
  }, info
end

local function autocmd_display(autocmd)
  local group = autocmd.group_name or 'None'
  local event = autocmd.event or 'Unknown'
  local pattern = autocmd_pattern(autocmd)
  local desc = autocmd.desc or ''

  return string.format('%-4s %-22s %-18s %-28s %s', autocmd.id or '-', group, event, pattern, desc)
end

local function autocmd_items()
  local items = vim.tbl_map(
    function(autocmd)
      return {
        autocmd = autocmd,
        text = autocmd_display(autocmd),
      }
    end,
    vim.api.nvim_get_autocmds({})
  )

  table.sort(items, function(a, b)
    if a.text == b.text then return (a.autocmd.id or 0) < (b.autocmd.id or 0) end
    return a.text < b.text
  end)

  return items
end

local function autocmd_preview(buf_id, item)
  if type(item) ~= 'table' or type(item.autocmd) ~= 'table' then return end

  local autocmd = item.autocmd
  local callback_location, callback_info = autocmd_callback_location(autocmd.callback)
  local lines = {
    'Id: ' .. (autocmd.id or '-'),
    'Group: ' .. (autocmd.group_name or 'None'),
    'Event: ' .. (autocmd.event or 'Unknown'),
    'Pattern: ' .. autocmd_pattern(autocmd),
  }

  if autocmd.desc and autocmd.desc ~= '' then table.insert(lines, 'Description: ' .. autocmd.desc) end
  if autocmd.once then table.insert(lines, 'Once: true') end
  if autocmd.nested then table.insert(lines, 'Nested: true') end

  table.insert(lines, '')

  if autocmd.command and autocmd.command ~= '' then
    table.insert(lines, 'Command:')
    table.insert(lines, autocmd.command)
  elseif callback_location then
    table.insert(lines, 'Callback:')
    table.insert(lines, callback_location.path .. ':' .. callback_location.start)

    local ok, file_lines = pcall(vim.fn.readfile, callback_location.path)
    if ok then
      local start = math.max(callback_location.start, 1)
      local finish = math.min(callback_location.finish, start + 40)

      table.insert(lines, '')
      table.insert(lines, 'Source:')
      for lnum = start, finish do
        if file_lines[lnum] ~= nil then table.insert(lines, string.format('%4d: %s', lnum, file_lines[lnum])) end
      end

      if callback_location.finish > finish then table.insert(lines, '...') end
    end
  elseif callback_info then
    table.insert(lines, 'Callback:')
    vim.list_extend(lines, vim.split(vim.inspect(callback_info), '\n'))
  else
    table.insert(lines, 'Action: <none>')
  end

  vim.bo[buf_id].filetype = 'text'
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
end

local function autocmd_choose(item)
  if type(item) ~= 'table' or type(item.autocmd) ~= 'table' then return end

  local location = autocmd_callback_location(item.autocmd.callback)
  if not location then return end

  local state = require('mini.pick').get_picker_state()
  local target = state and state.windows.target or nil
  if not (target and vim.api.nvim_win_is_valid(target)) then return end

  vim.api.nvim_win_call(target, function()
    vim.cmd('edit ' .. vim.fn.fnameescape(location.path))
    vim.api.nvim_win_set_cursor(0, { math.max(location.start, 1), 0 })
  end)
end

function M.autocmds()
  return require('mini.pick').start({
    source = {
      items = autocmd_items,
      name = 'Autocommands',
      preview = autocmd_preview,
      choose = autocmd_choose,
    },
  })
end

-- ┌───────────────────────────────────────────┐
-- │ Actions custom picker                     │
-- └───────────────────────────────────────────┘

local function action_items()
  local actions = {
    {
      group = 'Buffers',
      mode = 'n',
      key = '<C-[>',
      invoke = "require('neocraft.actions').previous_buffer()",
      desc = 'Previous buffer',
      run = function() require('neocraft.actions').previous_buffer() end,
    },
    {
      group = 'Buffers',
      mode = 'n',
      key = '<C-]>',
      invoke = "require('neocraft.actions').next_buffer()",
      desc = 'Next buffer',
      run = function() require('neocraft.actions').next_buffer() end,
    },
    {
      group = 'Buffers',
      mode = 'n',
      key = '<C-c>',
      invoke = "require('neocraft.actions').delete_buffer()",
      desc = 'Delete current buffer',
      run = function() require('neocraft.actions').delete_buffer() end,
    },
    {
      group = 'Buffers',
      mode = 'n',
      key = '<C-n>',
      invoke = "require('neocraft.actions').new_buffer()",
      desc = 'New buffer',
      run = function() require('neocraft.actions').new_buffer() end,
    },
    {
      group = 'Buffers',
      mode = 'Not set',
      key = 'Not set',
      invoke = ':NeocraftBufferDelete',
      desc = 'Delete current buffer',
      run = function() require('neocraft.actions').buffer_delete_command() end,
    },
    {
      group = 'Buffers',
      mode = 'Not set',
      key = 'Not set',
      invoke = ':NeocraftBufferWipeout',
      desc = 'Wipe out current buffer',
      run = function() require('neocraft.actions').buffer_wipeout_command() end,
    },
    {
      group = 'Pickers',
      mode = 'n',
      key = '<C-p>',
      invoke = "require('neocraft.actions').show_action_picker()",
      desc = 'Open action picker',
      run = function() require('neocraft.actions').show_action_picker() end,
    },
    {
      group = 'Editing',
      mode = 'n',
      key = '<Esc>',
      invoke = "require('neocraft.actions').clear_search()",
      desc = 'Clear search highlight',
      run = function() require('neocraft.actions').clear_search() end,
    },
    {
      group = 'Editing',
      mode = 'n',
      key = '<C-s>',
      invoke = "require('neocraft.actions').save()",
      desc = 'Save current file',
      run = function() require('neocraft.actions').save() end,
    },
    {
      group = 'Editing',
      mode = 'i,x',
      key = '<C-s>',
      invoke = "require('neocraft.actions').save_and_normal_mode()",
      desc = 'Save and return to Normal mode',
      run = function() require('neocraft.actions').save_and_normal_mode() end,
    },
    {
      group = 'Files',
      mode = 'n',
      key = '<C-x>',
      invoke = "require('neocraft.plugins.mini').open_files()",
      desc = 'Toggle file explorer',
      run = function() require('neocraft.plugins.mini').open_files() end,
    },
    {
      group = 'Terminal',
      mode = 'n,t',
      key = '<C-/>',
      invoke = "require('neocraft.terminal').toggle()",
      desc = 'Toggle floating terminal',
      run = function() require('neocraft.terminal').toggle() end,
    },
    {
      group = 'Git',
      mode = 'n',
      key = '<C-Space>',
      invoke = "require('neocraft.plugins.git').toggle_overlay()",
      desc = 'Toggle diff overlay',
      run = function() require('neocraft.plugins.git').toggle_overlay() end,
    },
    {
      group = 'Git',
      mode = 'n,x',
      key = 'go',
      invoke = "require('neocraft.plugins.git').open()",
      desc = 'Git open item at cursor',
      run = function() require('neocraft.plugins.git').open() end,
    },
    {
      group = 'Editing',
      mode = 'n,x',
      key = '<M-j>',
      invoke = "require('neocraft.actions').move_lines_down()",
      desc = 'Move line or selection down',
      run = function() require('neocraft.actions').move_lines_down() end,
    },
    {
      group = 'Editing',
      mode = 'n,x',
      key = '<M-k>',
      invoke = "require('neocraft.actions').move_lines_up()",
      desc = 'Move line or selection up',
      run = function() require('neocraft.actions').move_lines_up() end,
    },
    {
      group = 'Editing',
      mode = 'n',
      key = '<M-h>',
      invoke = "require('neocraft.actions').scroll_view_left()",
      desc = 'Scroll view left',
      run = function() require('neocraft.actions').scroll_view_left() end,
    },
    {
      group = 'Editing',
      mode = 'n',
      key = '<M-H>',
      invoke = "require('neocraft.actions').scroll_view_half_left()",
      desc = 'Scroll view half-screen left',
      run = function() require('neocraft.actions').scroll_view_half_left() end,
    },
    {
      group = 'Editing',
      mode = 'i,t,c',
      key = '<M-h>',
      invoke = "require('neocraft.actions').move_left()",
      desc = 'Move left',
      run = function() require('neocraft.actions').move_left() end,
    },
    {
      group = 'Editing',
      mode = 'i,t',
      key = '<M-j>',
      invoke = "require('neocraft.actions').move_down()",
      desc = 'Move down',
      run = function() require('neocraft.actions').move_down() end,
    },
    {
      group = 'Editing',
      mode = 'i,t',
      key = '<M-k>',
      invoke = "require('neocraft.actions').move_up()",
      desc = 'Move up',
      run = function() require('neocraft.actions').move_up() end,
    },
    {
      group = 'Editing',
      mode = 'n',
      key = '<M-l>',
      invoke = "require('neocraft.actions').scroll_view_right()",
      desc = 'Scroll view right',
      run = function() require('neocraft.actions').scroll_view_right() end,
    },
    {
      group = 'Editing',
      mode = 'n',
      key = '<M-L>',
      invoke = "require('neocraft.actions').scroll_view_half_right()",
      desc = 'Scroll view half-screen right',
      run = function() require('neocraft.actions').scroll_view_half_right() end,
    },
    {
      group = 'Editing',
      mode = 'i,t,c',
      key = '<M-l>',
      invoke = "require('neocraft.actions').move_right()",
      desc = 'Move right',
      run = function() require('neocraft.actions').move_right() end,
    },
    {
      group = 'Notifications',
      mode = 'Not set',
      key = 'Not set',
      invoke = ':NeocraftNotifications',
      desc = 'Show notification history',
      run = function() require('neocraft.actions').show_notifications() end,
    },
    {
      group = 'Notifications',
      mode = 'Not set',
      key = 'Not set',
      invoke = ':NeocraftNotificationsClear',
      desc = 'Clear visible notifications',
      run = function() require('neocraft.actions').clear_notifications() end,
    },
    {
      group = 'Plugins',
      mode = 'Not set',
      key = 'Not set',
      invoke = ':NeocraftPack',
      desc = 'Show vim.pack groups',
      run = function() require('neocraft.actions').show_pack() end,
    },
    {
      group = 'Session',
      mode = 'i,n,s,x',
      key = '<C-S-r>',
      invoke = "require('neocraft.actions').restart_neovim()",
      desc = 'Restart Neovim',
      run = function() require('neocraft.actions').restart_neovim() end,
    },
    {
      group = 'Session',
      mode = 'n',
      key = '<C-q>',
      invoke = "require('neocraft.actions').quit_neovim()",
      desc = 'Quit Neovim',
      run = function() require('neocraft.actions').quit_neovim() end,
    },
    {
      group = 'Editing',
      mode = 't',
      key = '<Esc><Esc>',
      invoke = "require('neocraft.actions').exit_terminal_mode()",
      desc = 'Exit terminal mode',
      run = function() require('neocraft.actions').exit_terminal_mode() end,
    },
    {
      group = 'Windows',
      mode = 'n',
      key = '<C-CR>',
      invoke = "require('neocraft.actions').toggle_maximized()",
      desc = 'Toggle maximized window',
      run = function() require('neocraft.actions').toggle_maximized() end,
    },
    {
      group = 'Windows',
      mode = 'n,t',
      key = '<C-h>',
      invoke = "require('neocraft.actions').focus_left()",
      desc = 'Focus window to the left',
      run = function() require('neocraft.actions').focus_left() end,
    },
    {
      group = 'Windows',
      mode = 'n,t',
      key = '<C-j>',
      invoke = "require('neocraft.actions').focus_down()",
      desc = 'Focus window below',
      run = function() require('neocraft.actions').focus_down() end,
    },
    {
      group = 'Windows',
      mode = 'n,t',
      key = '<C-k>',
      invoke = "require('neocraft.actions').focus_up()",
      desc = 'Focus window above',
      run = function() require('neocraft.actions').focus_up() end,
    },
    {
      group = 'Windows',
      mode = 'n,t',
      key = '<C-l>',
      invoke = "require('neocraft.actions').focus_right()",
      desc = 'Focus window to the right',
      run = function() require('neocraft.actions').focus_right() end,
    },
    {
      group = 'Windows',
      mode = 'n',
      key = '<C-Left>',
      invoke = "require('neocraft.actions').resize_left()",
      desc = 'Decrease window width',
      run = function() require('neocraft.actions').resize_left() end,
    },
    {
      group = 'Windows',
      mode = 'n',
      key = '<C-Down>',
      invoke = "require('neocraft.actions').resize_down()",
      desc = 'Decrease window height',
      run = function() require('neocraft.actions').resize_down() end,
    },
    {
      group = 'Windows',
      mode = 'n',
      key = '<C-Up>',
      invoke = "require('neocraft.actions').resize_up()",
      desc = 'Increase window height',
      run = function() require('neocraft.actions').resize_up() end,
    },
    {
      group = 'Windows',
      mode = 'n',
      key = '<C-Right>',
      invoke = "require('neocraft.actions').resize_right()",
      desc = 'Increase window width',
      run = function() require('neocraft.actions').resize_right() end,
    },
  }

  for _, item in ipairs(actions) do
    item.group = item.group or 'Other'
    item.mode = item.mode or 'Not set'
    item.key = item.key or 'Not set'
    item.text = string.format(
      '%-8s │ %-12s │ %-35s │ %-14s │ %s',
      item.mode,
      item.key,
      item.desc,
      item.group,
      item.invoke
    )
  end

  table.sort(actions, function(a, b)
    if a.group == b.group then return a.invoke < b.invoke end
    return a.group < b.group
  end)

  return actions
end

local function action_preview(buf_id, item)
  if type(item) ~= 'table' then return end

  local lines = {
    'Group: ' .. (item.group or 'Other'),
    'Mode: ' .. (item.mode or 'Not set'),
    'Keymap: ' .. (item.key or 'Not set'),
    'Invoke: ' .. (item.invoke or ''),
    '',
    item.desc or '',
  }

  vim.bo[buf_id].filetype = 'text'
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
end

function M.actions()
  return require('mini.pick').start({
    source = {
      items = action_items,
      name = 'Actions',
      preview = action_preview,
      choose = function(item)
        if type(item) ~= 'table' or type(item.run) ~= 'function' then return end
        vim.schedule(item.run)
      end,
    },
  })
end

-- ┌───────────────────────────────────────────┐
-- │ Quickfix/Location list custom pickers     │
-- └───────────────────────────────────────────┘

function M.quickfix_list()
  return mini_api().pick_extra('list', { scope = 'quickfix' }, {
    source = { name = 'Quickfix List' },
  })
end

function M.location_list()
  return mini_api().pick_extra('list', { scope = 'location' }, {
    source = { name = 'Location List' },
  })
end

-- ┌───────────────────────────────────────────┐
-- │ Pickers registry custom picker            │
-- └───────────────────────────────────────────┘

local function registry_picker_names()
  local names = vim.tbl_keys(require('mini.pick').registry)
  table.sort(names)
  return names
end

local registry_runners = {
  actions = function() M.actions() end,
  files = function(buf) mini_api().pick_files(buf) end,
  grep = function(buf) mini_api().pick_builtin('grep', nil, { buf = buf }) end,
  grep_cword = function(buf) M.grep_cword(buf) end,
  grep_live = function(buf) mini_api().grep_live(buf) end,
  location_list = function() M.location_list() end,
  quickfix_list = function() M.quickfix_list() end,
  resume = function() mini_api().resume_picker() end,
}

function M.registry()
  local mini_pick = require('mini.pick')

  mini_pick.start({
    source = {
      items = registry_picker_names,
      name = 'Pickers',
      choose = function(item)
        local state = mini_pick.get_picker_state()
        local target_win = state and state.windows.target or nil
        local target_buf = target_win and vim.api.nvim_win_is_valid(target_win) and vim.api.nvim_win_get_buf(target_win)
          or 0
        local picker = mini_pick.registry[item]
        local runner = registry_runners[item]
        local run = runner and function() runner(target_buf) end
          or function()
            if type(picker) ~= 'function' then
              vim.notify('Unknown picker: ' .. item, vim.log.levels.ERROR)
              return
            end

            picker()
          end

        vim.schedule(run)
      end,
    },
  })
end

return M
