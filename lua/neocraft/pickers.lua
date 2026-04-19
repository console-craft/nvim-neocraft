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
-- │ TODOs custom picker                       │
-- └───────────────────────────────────────────┘

local todos_picker_ns = vim.api.nvim_create_namespace('neocraft_todos_picker')
local todos_preview_ns = vim.api.nvim_create_namespace('neocraft_todos_preview')

local todos_highlights = {
  ERROR = 'MiniHipatternsFixme',
  DANGER = 'MiniHipatternsFixme',
  CRITICAL = 'MiniHipatternsFixme',
  FAIL = 'MiniHipatternsFixme',
  BUG = 'MiniHipatternsFixme',
  FIXME = 'MiniHipatternsFixme',
  WARNING = 'MiniHipatternsHack',
  CAUTION = 'MiniHipatternsHack',
  IMPORTANT = 'MiniHipatternsHack',
  WARN = 'MiniHipatternsHack',
  DEPRECATED = 'MiniHipatternsHack',
  WIP = 'MiniHipatternsHack',
  TEMP = 'MiniHipatternsTodo',
  TEMPORARY = 'MiniHipatternsTodo',
  TODO = 'MiniHipatternsTodo',
  SKIP = 'MiniHipatternsTodo',
  PATCH = 'MiniHipatternsTodo',
  XXX = 'MiniHipatternsTodo',
  INFO = 'MiniHipatternsNote',
  HINT = 'MiniHipatternsNote',
  NOTE = 'MiniHipatternsNote',
  TIP = 'MiniHipatternsNote',
  EXAMPLE = 'MiniHipatternsNote',
  DOCS = 'MiniHipatternsNote',
}

local function highlight_todos(buf_id, ns_id)
  vim.api.nvim_buf_clear_namespace(buf_id, ns_id, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  local extmark_opts = { hl_mode = 'combine', priority = 210 }

  for row, line in ipairs(lines) do
    for word, hl_group in pairs(todos_highlights) do
      local init = 1
      while true do
        local from, to = line:find('%f[%w]' .. word .. '%f[%W]', init)
        if from == nil then break end

        extmark_opts.hl_group = hl_group
        extmark_opts.end_row = row - 1
        extmark_opts.end_col = to
        vim.api.nvim_buf_set_extmark(buf_id, ns_id, row - 1, from - 1, extmark_opts)

        init = to + 1
      end
    end
  end
end

local function todos_show(buf_id, items, query)
  require('mini.pick').default_show(buf_id, items, query)
  highlight_todos(buf_id, todos_picker_ns)
end

local function todos_preview(buf_id, item)
  require('mini.pick').default_preview(buf_id, item)
  highlight_todos(buf_id, todos_preview_ns)
end

function M.todos(buf, opts)
  opts = vim.tbl_deep_extend('force', {
    buf = buf,
    source = {
      name = 'TODOs',
      preview = todos_preview,
      show = todos_show,
    },
  }, opts or {})

  return mini_api().pick_builtin('grep', {
    pattern = [[\b(ERROR|DANGER|CRITICAL|FAIL|BUG|FIXME|WARNING|CAUTION|IMPORTANT|WARN|DEPRECATED|WIP|TEMP|TEMPORARY|TODO|SKIP|PATCH|XXX|INFO|HINT|NOTE|TIP|EXAMPLE|DOCS)\b]],
  }, opts)
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

local function run_copilot_action(action)
  return function() require('neocraft.plugins.lsp')[action]() end
end

local function run_lsp_action(action)
  return function() require('neocraft.plugins.lsp')[action]() end
end

local function notify_specific_mode_only(action, mode)
  return function() vim.notify(action .. ' works from ' .. mode .. ' mode only', vim.log.levels.INFO) end
end

local function feedkeys(keys)
  return function() vim.api.nvim_feedkeys(vim.keycode(keys), 'm', false) end
end

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
      group = 'Lists',
      mode = 'n',
      key = '<Leader>lt',
      invoke = "require('neocraft.pickers').todos()",
      desc = 'Project TODOs',
      run = function() require('neocraft.pickers').todos() end,
    },
    {
      group = 'Editing',
      mode = 'n',
      key = '<Esc>',
      invoke = "require('neocraft.actions').clear_on_escape()",
      desc = 'Multiple clearing actions',
      run = function() require('neocraft.actions').clear_on_escape() end,
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
      group = 'Git',
      mode = 'n',
      key = '[h',
      invoke = "require('neocraft.plugins.git').goto_hunk('prev')",
      desc = 'Previous git hunk',
      run = feedkeys('[h'),
    },
    {
      group = 'Git',
      mode = 'n',
      key = ']h',
      invoke = "require('neocraft.plugins.git').goto_hunk('next')",
      desc = 'Next git hunk',
      run = feedkeys(']h'),
    },
    {
      group = 'Git',
      mode = 'n',
      key = '[H',
      invoke = "require('neocraft.plugins.git').goto_hunk('first')",
      desc = 'First git hunk',
      run = feedkeys('[H'),
    },
    {
      group = 'Git',
      mode = 'n',
      key = ']H',
      invoke = "require('neocraft.plugins.git').goto_hunk('last')",
      desc = 'Last git hunk',
      run = feedkeys(']H'),
    },
    {
      group = 'Git',
      mode = 'n',
      key = '[g',
      invoke = "require('neocraft.plugins.git').prev_pending_file(false)",
      desc = 'Previous unstaged git file',
      run = feedkeys('[g'),
    },
    {
      group = 'Git',
      mode = 'n',
      key = ']g',
      invoke = "require('neocraft.plugins.git').next_pending_file(false)",
      desc = 'Next unstaged git file',
      run = feedkeys(']g'),
    },
    {
      group = 'Git',
      mode = 'n',
      key = '[G',
      invoke = "require('neocraft.plugins.git').prev_pending_file(true)",
      desc = 'Previous staged git file',
      run = feedkeys('[G'),
    },
    {
      group = 'Git',
      mode = 'n',
      key = ']G',
      invoke = "require('neocraft.plugins.git').next_pending_file(true)",
      desc = 'Next staged git file',
      run = feedkeys(']G'),
    },
    {
      group = 'Git',
      mode = 'n,o,x',
      key = 'gh',
      invoke = 'gh',
      desc = 'Apply hunk',
      run = feedkeys('gh'),
    },
    {
      group = 'Git',
      mode = 'n,o,x',
      key = 'gH',
      invoke = 'gH',
      desc = 'Reset hunk',
      run = feedkeys('gH'),
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
      key = '[p',
      invoke = '[p',
      desc = 'Paste above',
      run = feedkeys('[p'),
    },
    {
      group = 'Editing',
      mode = 'n',
      key = ']p',
      invoke = ']p',
      desc = 'Paste below',
      run = feedkeys(']p'),
    },
    {
      group = 'Editing',
      mode = 'n',
      key = 'gV',
      invoke = 'gV',
      desc = 'Reselect last paste/change',
      run = feedkeys('gV'),
    },
    {
      group = 'Editing',
      mode = 'n',
      key = 's',
      invoke = 's',
      desc = 'Start jump',
      run = feedkeys('s'),
    },
    {
      group = 'Editing',
      mode = 'n,x',
      key = 'ys',
      invoke = 'ys',
      desc = 'Add surrounding',
      run = feedkeys('ys'),
    },
    {
      group = 'Editing',
      mode = 'n',
      key = 'ds',
      invoke = 'ds',
      desc = 'Delete surrounding',
      run = feedkeys('ds'),
    },
    {
      group = 'Editing',
      mode = 'n',
      key = 'cs',
      invoke = 'cs',
      desc = 'Change surrounding',
      run = feedkeys('cs'),
    },
    {
      group = 'Editing',
      mode = 'n',
      key = 'yss',
      invoke = 'yss',
      desc = 'Add surrounding to line',
      run = feedkeys('yss'),
    },
    {
      group = 'Editing',
      mode = 'x',
      key = 'S',
      invoke = 'S',
      desc = 'Surround selection',
      run = notify_specific_mode_only('S', 'Visual'),
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
      key = '[<Tab>',
      invoke = '[<Tab>',
      desc = 'Previous tab',
      run = feedkeys('[<Tab>'),
    },
    {
      group = 'Windows',
      mode = 'n',
      key = ']<Tab>',
      invoke = ']<Tab>',
      desc = 'Next tab',
      run = feedkeys(']<Tab>'),
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
      mode = 'n,t',
      key = '<C-/>',
      invoke = "require('neocraft.terminal').toggle()",
      desc = 'Toggle floating terminal',
      run = function() require('neocraft.terminal').toggle() end,
    },
    {
      group = 'Coding',
      mode = 'n',
      key = 'K',
      invoke = 'K',
      desc = 'Hover documentation',
      run = feedkeys('K'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = 'gd',
      invoke = 'gd',
      desc = 'Go to definition / tag',
      run = feedkeys('gd'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = 'gD',
      invoke = 'gD',
      desc = 'Go to declaration / TS: Go to source definition',
      run = feedkeys('gD'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = 'grr',
      invoke = 'grr',
      desc = 'Go to references',
      run = feedkeys('grr'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = 'gri',
      invoke = 'gri',
      desc = 'Go to implementation',
      run = feedkeys('gri'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = 'grt',
      invoke = 'grt',
      desc = 'Go to type definition',
      run = feedkeys('grt'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = 'gR',
      invoke = "require('neocraft.plugins.lsp').typescript_file_references()",
      desc = 'TS: Go to file references',
      run = run_lsp_action('typescript_file_references'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = 'grn',
      invoke = 'grn',
      desc = 'Rename symbol',
      run = feedkeys('grn'),
    },
    {
      group = 'Coding',
      mode = 'n,x',
      key = 'gra',
      invoke = 'gra',
      desc = 'Code actions',
      run = feedkeys('gra'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = '<Leader>cla',
      invoke = "require('neocraft.plugins.lsp').show_attached_clients()",
      desc = 'Attached LSP clients',
      run = run_lsp_action('show_attached_clients'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = '<Leader>clc',
      invoke = "require('neocraft.plugins.format').info()",
      desc = 'Conform info',
      run = function() require('neocraft.plugins.format').info() end,
    },
    {
      group = 'Coding',
      mode = 'n',
      key = '<Leader>cll',
      invoke = ':LspInfo',
      desc = 'LSP info',
      run = function() vim.cmd.LspInfo() end,
    },
    {
      group = 'Coding',
      mode = 'n',
      key = '<Leader>cO',
      invoke = "require('neocraft.plugins.lsp').typescript_organize_imports()",
      desc = 'TS: Organize imports',
      run = run_lsp_action('typescript_organize_imports'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = '<Leader>cO',
      invoke = "require('neocraft.plugins.lsp').python_organize_imports()",
      desc = 'Py: Organize imports',
      run = run_lsp_action('python_organize_imports'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = '<Leader>cM',
      invoke = "require('neocraft.plugins.lsp').typescript_add_missing_imports()",
      desc = 'TS: Add missing imports',
      run = run_lsp_action('typescript_add_missing_imports'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = '<Leader>cU',
      invoke = "require('neocraft.plugins.lsp').typescript_remove_unused_imports()",
      desc = 'TS: Remove unused imports',
      run = run_lsp_action('typescript_remove_unused_imports'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = '<Leader>cR',
      invoke = "require('neocraft.plugins.lsp').typescript_restart()",
      desc = 'TS: Restart server',
      run = run_lsp_action('typescript_restart'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = '<Leader>cV',
      invoke = "require('neocraft.plugins.lsp').typescript_select_version()",
      desc = 'TS: Select workspace version',
      run = run_lsp_action('typescript_select_version'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = '<Leader>cV',
      invoke = "require('neocraft.plugins.lsp').python_select_venv()",
      desc = 'Py: Select virtual environment',
      run = run_lsp_action('python_select_venv'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = '<Leader>clt',
      invoke = "require('neocraft.plugins.lsp').typescript_open_log()",
      desc = 'TS: Open server log',
      run = run_lsp_action('typescript_open_log'),
    },
    {
      group = 'Coding',
      mode = 'i',
      key = '<C-k>',
      invoke = 'vim.lsp.buf.signature_help()',
      desc = 'Signature help',
      run = vim.lsp.buf.signature_help,
    },
    {
      group = 'Coding',
      mode = 'i',
      key = '<C-Space>',
      invoke = '<C-Space>',
      desc = 'Manually trigger completions',
      run = notify_specific_mode_only('<C-Space>', 'Insert'),
    },
    {
      group = 'Coding',
      mode = 'i',
      key = '<C-e>',
      invoke = '<C-e>',
      desc = 'Close completions / Accept to EOL',
      run = notify_specific_mode_only('<C-e>', 'Insert'),
    },
    {
      group = 'Coding',
      mode = 'i',
      key = '<C-]>',
      invoke = '<C-]>',
      desc = 'Dismiss active inline completion',
      run = notify_specific_mode_only('<C-]>', 'Insert'),
    },
    {
      group = 'Coding',
      mode = 'i',
      key = '<M-[>',
      invoke = '<M-[>',
      desc = 'Previous inline completion',
      run = notify_specific_mode_only('<M-[>', 'Insert'),
    },
    {
      group = 'Coding',
      mode = 'i',
      key = '<M-]>',
      invoke = '<M-]>',
      desc = 'Next / Retrigger inline completion',
      run = notify_specific_mode_only('<M-]>', 'Insert'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = '[e',
      invoke = '[e',
      desc = 'Jump to previous error',
      run = feedkeys('[e'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = ']e',
      invoke = ']e',
      desc = 'Jump to next error',
      run = feedkeys(']e'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = '[w',
      invoke = '[w',
      desc = 'Jump to previous warning',
      run = feedkeys('[w'),
    },
    {
      group = 'Coding',
      mode = 'n',
      key = ']w',
      invoke = ']w',
      desc = 'Jump to next warning',
      run = feedkeys(']w'),
    },
    {
      group = 'Coding',
      mode = 'Not set',
      key = 'Not set',
      invoke = ':LspCopilotSignIn',
      desc = 'Sign in to Copilot',
      run = run_copilot_action('copilot_sign_in'),
    },
    {
      group = 'Coding',
      mode = 'Not set',
      key = 'Not set',
      invoke = ':LspCopilotSignOut',
      desc = 'Sign out of Copilot',
      run = run_copilot_action('copilot_sign_out'),
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
      '%-8s │ %-12s │ %-50s │ %-14s │ %s',
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
-- │ Worktrees custom pickers                  │
-- └───────────────────────────────────────────┘

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

function M.worktree_bases(on_choice)
  local worktrees = require('neocraft.worktrees')
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

function M.worktrees(on_choice, opts)
  opts = vim.tbl_extend('force', {
    empty_message = 'No worktrees found for this project',
    exclude_current = false,
    include_main = true,
    name = 'Worktrees',
  }, opts or {})

  local worktrees = require('neocraft.worktrees')
  local items, err = worktrees.list()

  if not items then
    vim.notify(err or 'Could not load worktrees', vim.log.levels.WARN)
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

local function read_preview_chunk(path)
  local fd = vim.uv.fs_open(path, 'r', 438)
  if fd == nil then return nil end

  local chunk = vim.uv.fs_read(fd, 4096, 0)
  vim.uv.fs_close(fd)

  return chunk
end

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

function M.worktree_files(on_choice)
  local worktrees = require('neocraft.worktrees')
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

-- ┌───────────────────────────────────────────┐
-- │ Git branches custom pickers               │
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

function M.git_local_branches(on_choice)
  local git = require('neocraft.plugins.git')
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
  local git = require('neocraft.plugins.git')
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
  todos = function(buf) M.todos(buf) end,
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
