local pack = require('neocraft.core.pack')
local keymaps = require('neocraft.config.keymaps')
local pickers = require('neocraft.pickers')
local root = require('neocraft.core.root')
local visits = require('neocraft.visits')

local use_icons = vim.g.have_nerd_font == true
local M = {}

local prose_filetypes = {
  'asciidoc',
  'gitcommit',
  'markdown',
  'norg',
  'org',
  'plaintex',
  'rst',
  'tex',
  'text',
}

local function is_prose_buffer(buf) return vim.tbl_contains(prose_filetypes, vim.bo[buf].filetype) end

pack.add('mini', {
  { src = 'https://github.com/nvim-mini/mini.nvim' },
})

-- ┌───────────────────────────────────────────┐
-- │ mini.icons                                │
-- └───────────────────────────────────────────┘

Lib.now(function()
  local mini_icons = require('mini.icons')
  local ext3_blocklist = { scm = true, txt = true, yml = true }
  local ext4_blocklist = { json = true, yaml = true }
  mini_icons.setup({
    -- Set up to not prefer extension-based icon for some extensions
    use_file_extension = function(ext, _) return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)]) end,
  })

  Lib.later(mini_icons.mock_nvim_web_devicons)
  Lib.later(mini_icons.tweak_lsp_kind)
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.notify                               │
-- └───────────────────────────────────────────┘

Lib.now(function()
  local mini_notify = require('mini.notify')
  mini_notify.setup()

  vim.notify = mini_notify.make_notify({
    -- Keep errors at default duration, decrease the rest, show debug messages
    ERROR = { duration = 5000 },
    WARN = { duration = 2500 },
    INFO = { duration = 2500 },
    DEBUG = { duration = 2500 },
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.statusline                           │
-- └───────────────────────────────────────────┘

Lib.now(function()
  local statusline = require('mini.statusline')
  statusline.setup({ use_icons = use_icons })

  statusline.section_location = function() return '%2l:%-2v' end
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.tabline                              │
-- └───────────────────────────────────────────┘

Lib.now(function()
  local tabline = require('mini.tabline')
  local plain_label = function(label) return string.format(' %s ', label) end

  tabline.setup({
    format = function(buf_id, label)
      local name = vim.api.nvim_buf_get_name(buf_id)
      if type(name) ~= 'string' or name == '' then return plain_label(label) end

      local ok, formatted = pcall(tabline.default_format, buf_id, label)
      return ok and formatted or plain_label(label)
    end,
    show_icons = use_icons,
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.sessions                             │
-- └───────────────────────────────────────────┘

Lib.now(
  function()
    require('mini.sessions').setup({
      autoread = false,
      autowrite = false,
      directory = vim.fs.joinpath(vim.fn.stdpath('state'), 'sessions'),
      file = '',
      force = {
        read = false,
        write = true,
        delete = false,
      },
      verbose = {
        read = false,
        write = false,
        delete = true,
      },
    })
  end
)

-- ┌───────────────────────────────────────────┐
-- │ mini.visits                               │
-- └───────────────────────────────────────────┘

Lib.later(function()
  require('mini.visits').setup({
    silent = true,
    store = {
      autowrite = true,
      path = vim.fs.joinpath(vim.fn.stdpath('state'), 'mini-visits-index'),
    },
    track = {
      event = '',
    },
  })

  visits.setup()
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.extra                                │
-- └───────────────────────────────────────────┘

Lib.later(function() require('mini.extra').setup() end)

-- ┌───────────────────────────────────────────┐
-- │ mini.hipatterns                           │
-- └───────────────────────────────────────────┘

Lib.later(function()
  local hipatterns = require('mini.hipatterns')

  local function trim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end

  local function split_commas(value)
    local parts = {}

    for part in value:gmatch('[^,]+') do
      parts[#parts + 1] = trim(part)
    end

    return parts
  end

  local function split_spaces(value)
    local parts = {}

    for part in value:gmatch('%S+') do
      parts[#parts + 1] = part
    end

    return parts
  end

  local function parse_alpha(value)
    if value == nil or value == '' then return true end

    if vim.endswith(value, '%') then
      local percent = tonumber(value:sub(1, -2))
      return percent ~= nil and percent >= 0 and percent <= 100
    end

    local alpha = tonumber(value)
    return alpha ~= nil and alpha >= 0 and alpha <= 1
  end

  local function parse_rgb_channel(value)
    if vim.endswith(value, '%') then
      local percent = tonumber(value:sub(1, -2))
      if percent == nil or percent < 0 or percent > 100 then return nil end

      return math.floor((255 * percent / 100) + 0.5)
    end

    local channel = tonumber(value)
    if channel == nil or channel < 0 or channel > 255 then return nil end

    return math.floor(channel + 0.5)
  end

  local function parse_hue(value)
    local hue = value
    if vim.endswith(hue, 'deg') then hue = hue:sub(1, -4) end

    hue = tonumber(hue)
    if hue == nil then return nil end

    return (hue % 360) / 360
  end

  local function parse_percentage(value)
    if not vim.endswith(value, '%') then return nil end

    local percent = tonumber(value:sub(1, -2))
    if percent == nil or percent < 0 or percent > 100 then return nil end

    return percent / 100
  end

  local function hue_to_rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1 / 6 then return p + ((q - p) * 6 * t) end
    if t < 1 / 2 then return q end
    if t < 2 / 3 then return p + ((q - p) * ((2 / 3) - t) * 6) end
    return p
  end

  local function hsl_to_hex(h, s, l)
    if s == 0 then
      local channel = math.floor((l * 255) + 0.5)
      return string.format('#%02x%02x%02x', channel, channel, channel)
    end

    local q = l < 0.5 and (l * (1 + s)) or (l + s - (l * s))
    local p = 2 * l - q

    local r = math.floor((255 * hue_to_rgb(p, q, h + (1 / 3))) + 0.5)
    local g = math.floor((255 * hue_to_rgb(p, q, h)) + 0.5)
    local b = math.floor((255 * hue_to_rgb(p, q, h - (1 / 3))) + 0.5)

    return string.format('#%02x%02x%02x', r, g, b)
  end

  local function parse_css_body(match, names)
    local body
    for _, name in ipairs(names) do
      body = match:match('^' .. name .. '%((.*)%)$')
      if body ~= nil then break end
    end

    return body and trim(body) or nil
  end

  local function parse_function_parts(body)
    if body:find(',', 1, true) then return split_commas(body) end

    local components, alpha = body:match('^(.-)%s*/%s*(.-)$')
    local parts = split_spaces(components or body)
    if alpha ~= nil then parts[#parts + 1] = trim(alpha) end

    return parts
  end

  local function css_function_color_group(_, match)
    local rgb_body = parse_css_body(match, { 'rgb', 'rgba' })
    if rgb_body ~= nil then
      local parts = parse_function_parts(rgb_body)
      if #parts ~= 3 and #parts ~= 4 then return nil end
      if not parse_alpha(parts[4]) then return nil end

      local r = parse_rgb_channel(parts[1])
      local g = parse_rgb_channel(parts[2])
      local b = parse_rgb_channel(parts[3])
      if r == nil or g == nil or b == nil then return nil end

      local hex = string.format('#%02x%02x%02x', r, g, b)
      return hipatterns.compute_hex_color_group(hex, 'bg')
    end

    local hsl_body = parse_css_body(match, { 'hsl', 'hsla' })
    if hsl_body == nil then return nil end

    local parts = parse_function_parts(hsl_body)
    if #parts ~= 3 and #parts ~= 4 then return nil end
    if not parse_alpha(parts[4]) then return nil end

    local h = parse_hue(parts[1])
    local s = parse_percentage(parts[2])
    local l = parse_percentage(parts[3])
    if h == nil or s == nil or l == nil then return nil end

    return hipatterns.compute_hex_color_group(hsl_to_hex(h, s, l), 'bg')
  end

  -- category:  Dialog    Documentation   Planning      CI        Refactor      Code
  -- red:       ERROR     DANGER          CRITICAL      FAIL      BUG           FIXME
  -- orange:    WARNING   CAUTION         IMPORTANT     WARN      DEPRECATED    WIP
  -- yellow:    TEMP      TEMPORARY       TODO          SKIP      PATCH         XXX
  -- green:     SUCCESS   COMPLETED       DONE          OK        FIXES         FIX
  -- blue:      INFO      HINT            NOTE          TIP       EXAMPLE       DOCS

  hipatterns.setup({
    highlighters = {
      error = { pattern = '%f[%w]()ERROR()%f[%W]', group = 'MiniHipatternsFixme' },
      danger = { pattern = '%f[%w]()DANGER()%f[%W]', group = 'MiniHipatternsFixme' },
      critical = { pattern = '%f[%w]()CRITICAL()%f[%W]', group = 'MiniHipatternsFixme' },
      fail = { pattern = '%f[%w]()FAIL()%f[%W]', group = 'MiniHipatternsFixme' },
      bug = { pattern = '%f[%w]()BUG()%f[%W]', group = 'MiniHipatternsFixme' },
      fixme = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' },
      warning = { pattern = '%f[%w]()WARNING()%f[%W]', group = 'MiniHipatternsHack' },
      caution = { pattern = '%f[%w]()CAUTION()%f[%W]', group = 'MiniHipatternsHack' },
      important = { pattern = '%f[%w]()IMPORTANT()%f[%W]', group = 'MiniHipatternsHack' },
      warn = { pattern = '%f[%w]()WARN()%f[%W]', group = 'MiniHipatternsHack' },
      deprecated = { pattern = '%f[%w]()DEPRECATED()%f[%W]', group = 'MiniHipatternsHack' },
      wip = { pattern = '%f[%w]()WIP()%f[%W]', group = 'MiniHipatternsHack' },
      temp = { pattern = '%f[%w]()TEMP()%f[%W]', group = 'MiniHipatternsTodo' },
      temporary = { pattern = '%f[%w]()TEMPORARY()%f[%W]', group = 'MiniHipatternsTodo' },
      todo = { pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsTodo' },
      skip = { pattern = '%f[%w]()SKIP()%f[%W]', group = 'MiniHipatternsTodo' },
      patch = { pattern = '%f[%w]()PATCH()%f[%W]', group = 'MiniHipatternsTodo' },
      xxx = { pattern = '%f[%w]()XXX()%f[%W]', group = 'MiniHipatternsTodo' },
      success = { pattern = '%f[%w]()SUCCESS()%f[%W]', group = 'MiniHipatternsOK' },
      completed = { pattern = '%f[%w]()COMPLETED()%f[%W]', group = 'MiniHipatternsOK' },
      done = { pattern = '%f[%w]()DONE()%f[%W]', group = 'MiniHipatternsOK' },
      ok = { pattern = '%f[%w]()OK()%f[%W]', group = 'MiniHipatternsOK' },
      fixes = { pattern = '%f[%w]()FIXES()%f[%W]', group = 'MiniHipatternsOK' },
      fix = { pattern = '%f[%w]()FIX()%f[%W]', group = 'MiniHipatternsOK' },
      info = { pattern = '%f[%w]()INFO()%f[%W]', group = 'MiniHipatternsNote' },
      hint = { pattern = '%f[%w]()HINT()%f[%W]', group = 'MiniHipatternsNote' },
      note = { pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote' },
      tip = { pattern = '%f[%w]()TIP()%f[%W]', group = 'MiniHipatternsNote' },
      example = { pattern = '%f[%w]()EXAMPLE()%f[%W]', group = 'MiniHipatternsNote' },
      docs = { pattern = '%f[%w]()DOCS()%f[%W]', group = 'MiniHipatternsNote' },
      hex_color = hipatterns.gen_highlighter.hex_color(),
      rgb_color = {
        pattern = {
          '()%f[%a]rgb%b()()',
          '()%f[%a]rgba%b()()',
        },
        group = css_function_color_group,
      },
      hsl_color = {
        pattern = {
          '()%f[%a]hsl%b()()',
          '()%f[%a]hsla%b()()',
        },
        group = css_function_color_group,
      },
    },
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.map                                  │
-- └───────────────────────────────────────────┘

Lib.later(function()
  local map = require('mini.map')

  map.setup({
    symbols = {
      encode = map.gen_encode_symbols.dot('4x2'),
      scroll_line = '┃',
      scroll_view = '│',
    },
    integrations = {
      map.gen_integration.builtin_search(),
      map.gen_integration.diff(),
    },
    window = {
      focusable = true,
      width = 5,
      winblend = 15,
      show_integration_count = false,
      zindex = 50,
    },
  })

  map.open()
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.animate                              │
-- └───────────────────────────────────────────┘

Lib.later(function()
  local animate = require('mini.animate')
  local normal_scroll_timing = animate.gen_timing.linear({ duration = 110, unit = 'total' })
  local fast_scroll_timing = animate.gen_timing.linear({ duration = 10, unit = 'total' })

  local function adaptive_scroll_timing(step, total_steps)
    if total_steps >= 65 then return fast_scroll_timing(step, total_steps) end
    return normal_scroll_timing(step, total_steps)
  end

  animate.setup({
    cursor = { timing = animate.gen_timing.linear({ duration = 10, unit = 'total' }) },
    scroll = { timing = adaptive_scroll_timing },
    resize = { enable = false }, -- Resize animation causes issues with terminal buffer display.
    open = { timing = animate.gen_timing.linear({ duration = 10, unit = 'total' }) },
    close = { timing = animate.gen_timing.linear({ duration = 10, unit = 'total' }) },
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.completion                           │
-- └───────────────────────────────────────────┘

Lib.now(function()
  local process_items_opts = { kind_priority = { Text = -1, Snippet = 99 } }

  local process_items = function(items, base)
    return require('mini.completion').default_process_items(items, base, process_items_opts)
  end

  require('mini.completion').setup({
    lsp_completion = {
      auto_setup = false,
      source_func = 'omnifunc',
      process_items = process_items,
    },
    mappings = {
      force_twostep = '',
    },
    window = {
      info = { border = vim.o.winborder },
      signature = { border = vim.o.winborder },
    },
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.files                                │
-- └───────────────────────────────────────────┘

local function resolve_buf(buf) return (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf end

local function realpath(path) return root.realpath(path) end

local show_dotfiles = true

local function path_type(path)
  local stat = path and vim.uv.fs_stat(path) or nil
  return stat and stat.type or nil
end

local function files_anchor(buf)
  buf = resolve_buf(buf)

  local name = vim.api.nvim_buf_get_name(buf)
  local buftype = vim.bo[buf].buftype
  local fallback = root.get({ buf = buf })

  if name == '' or buftype ~= '' then return fallback end

  local normalized = realpath(name) or vim.fs.normalize(name)

  if path_type(normalized) ~= nil then return normalized end

  local parent = vim.fs.dirname(normalized)
  if path_type(parent) == 'directory' then return realpath(parent) or parent end

  return fallback
end

local function current_fs_entry() return require('mini.files').get_fs_entry() end

local function current_entry_path()
  local entry = current_fs_entry()
  return entry and entry.path or nil
end

local function current_entry_relative_path()
  local path = current_entry_path()
  if path == nil then return nil end

  local project_root = root.get()
  if project_root == nil then return path end

  return vim.fs.relpath(project_root, path) or path
end

local function yank_to_clipboard(value, message)
  if value == nil or value == '' then
    vim.notify('No path selected in file explorer', vim.log.levels.WARN)
    return
  end

  vim.fn.setreg('+', value)
  vim.api.nvim_echo({ { message, 'Normal' } }, false, {})
end

local function copy_entry_relative_path()
  yank_to_clipboard(current_entry_relative_path(), 'Yanked relative path to clipboard')
end

local function copy_entry_absolute_path() yank_to_clipboard(current_entry_path(), 'Yanked absolute path to clipboard') end

local function open_entry_with_system()
  local path = current_entry_path()
  if path == nil then
    vim.notify('No path selected in file explorer', vim.log.levels.WARN)
    return
  end

  vim.ui.open(path)
end

local function toggle_dotfiles()
  show_dotfiles = not show_dotfiles

  local filter = show_dotfiles and function() return true end
    or function(fs_entry) return not vim.startswith(fs_entry.name, '.') end

  require('mini.files').refresh({ content = { filter = filter } })
end

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

local function map_files_buffer(buf_id)
  vim.keymap.set('n', '<C-s>', function() split_entry('belowright horizontal') end, {
    buffer = buf_id,
    desc = 'Open file in horizontal split',
  })
  vim.keymap.set('n', '<C-v>', function() split_entry('belowright vertical') end, {
    buffer = buf_id,
    desc = 'Open file in vertical split',
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

function M.open_files(buf)
  local mini_files = require('mini.files')

  if mini_files.get_explorer_state() then
    mini_files.close()
    return
  end

  buf = resolve_buf(buf)

  local project_root = root.get({ buf = buf })
  mini_files.open(files_anchor(buf), false)
  mini_files.reveal_cwd()
  mini_files.set_bookmark('~', project_root, { desc = 'Project root' })
end

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

-- ┌───────────────────────────────────────────┐
-- │ mini.pick                                 │
-- └───────────────────────────────────────────┘

function M.grep_cword(buf, opts) return pickers.grep_cword(buf, opts) end

function M.pick_autocmds() return pickers.autocmds() end

function M.pick_registry() return pickers.registry() end

-- mini.pick setup

local function pick_cwd(buf, kind)
  local resolver = kind == 'git' and root.git or root.get
  return resolver({ buf = resolve_buf(buf) })
end

local function pick_start_opts(buf, opts, kind)
  local start_opts = vim.deepcopy(opts or {})
  start_opts.source = start_opts.source or {}
  start_opts.source.cwd = start_opts.source.cwd or pick_cwd(buf, kind)
  return start_opts
end

function M.pick_builtin(name, local_opts, opts)
  opts = vim.deepcopy(opts or {})

  local buf = opts.buf
  local kind = opts.kind or 'project'
  opts.buf = nil
  opts.kind = nil

  local builtin = require('mini.pick').builtin[name]
  if type(builtin) ~= 'function' then error(('Unknown MiniPick builtin: %s'):format(name)) end

  return builtin(local_opts, pick_start_opts(buf, opts, kind))
end

function M.pick_extra(name, local_opts, opts)
  opts = vim.deepcopy(opts or {})

  local buf = opts.buf
  local kind = opts.kind or 'project'
  opts.buf = nil
  opts.kind = nil

  local picker = require('mini.extra').pickers[name]
  if type(picker) ~= 'function' then error(('Unknown MiniExtra picker: %s'):format(name)) end

  return picker(local_opts, pick_start_opts(buf, opts, kind))
end

function M.pick_files(buf, opts)
  opts = vim.tbl_extend('force', { buf = buf }, opts or {})
  return M.pick_builtin('files', nil, opts)
end

function M.grep_live(buf, opts)
  opts = vim.tbl_extend('force', { buf = buf }, opts or {})
  return M.pick_builtin('grep_live', nil, opts)
end

function M.resume_picker() return require('mini.pick').builtin.resume() end

local win_config = function()
  local lines = vim.o.lines
  local columns = vim.o.columns
  local height = math.min(math.max(math.floor(lines * 0.75), 25), 50)
  local width = math.min(math.max(math.floor(columns * 0.90), 80), 180)
  height = math.min(height, lines - 2)
  width = math.min(width, columns - 4)
  return {
    anchor = 'NW',
    height = height,
    width = width,
    row = math.floor((lines - height) * 0.5),
    col = math.floor((columns - width) * 0.5),
  }
end

Lib.later(function()
  local mini_pick = require('mini.pick')

  mini_pick.setup({ window = { config = win_config } })
  mini_pick.registry.actions = pickers.actions
  mini_pick.registry.todos = pickers.todos
  mini_pick.registry.autocmds = pickers.autocmds
  mini_pick.registry.grep_cword = pickers.grep_cword
  mini_pick.registry.location_list = pickers.location_list
  mini_pick.registry.quickfix_list = pickers.quickfix_list
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.clue                                 │
-- └───────────────────────────────────────────┘

Lib.later(function()
  local clue = require('mini.clue')
  clue.setup({
    clues = {
      keymaps.leader_group_clues,
      clue.gen_clues.builtin_completion(),
      clue.gen_clues.g(),
      clue.gen_clues.marks(),
      clue.gen_clues.registers(),
      clue.gen_clues.square_brackets(),
      clue.gen_clues.windows({ submode_resize = true }),
      clue.gen_clues.z(),
    },
    triggers = {
      { mode = { 'n', 'x' }, keys = '<Leader>' },
      { mode = 'n', keys = [[\]] },
      { mode = { 'n', 'x' }, keys = '[' },
      { mode = { 'n', 'x' }, keys = ']' },
      { mode = 'i', keys = '<C-x>' },
      { mode = { 'n', 'x' }, keys = 'g' },
      { mode = { 'n', 'x' }, keys = "'" },
      { mode = { 'n', 'x' }, keys = '`' },
      { mode = { 'n', 'x' }, keys = '"' },
      { mode = { 'i', 'c' }, keys = '<C-r>' },
      { mode = 'n', keys = '<C-w>' },
      { mode = { 'n', 'x' }, keys = 'z' },
    },
    window = {
      delay = 200,
      config = { width = 'auto' },
    },
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.ai                                   │
-- └───────────────────────────────────────────┘

-- Example usage for mini.ai:
--  * ciq - [c]hange [i]nside [q]uotes
--  * di( - [d]elete [i]nside `(`
--  * yina - [y]ank [i]nside [n]ext [a]rgument
--  * yit - [y]ank [i]nside [t]ag
--  * vab - [v]isually select [a]round brackets (including object/array delimiters)
--  * viB - [v]isually select [i]nside [B]uffer (excluding trailing newlines)
--  * vif - [v]isually select [i]nside [f]unction call (function call arguments)
--  * vaf - [v]isually select [a]round [f]unction call (whole function call)
--  * yiF - [y]ank [i]nside [F]unction definition (function definition content)
--  * yaF - [y]ank [a]round [F]unction definition (whole function definition)
Lib.later(function()
  local ai = require('mini.ai')
  local mini_extra = require('mini.extra')
  ai.setup({
    custom_textobjects = {
      -- Make `aB` / `iB` act on around/inside whole [B]uffer
      B = mini_extra.gen_ai_spec.buffer(),
      -- Make `aF`/`iF` act on around/inside function definition (not call)
      F = ai.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),
    },
    search_method = 'cover',
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.jump2d                               │
-- └───────────────────────────────────────────┘

Lib.later(function()
  local jump2d = require('mini.jump2d')
  jump2d.setup({
    mappings = {
      start_jumping = 's',
    },
    spotter = jump2d.builtin_opts.word_start.spotter,
    allowed_windows = {
      not_current = false,
    },
    allowed_lines = {
      blank = false,
    },
    silent = true,
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.surround                             │
-- └───────────────────────────────────────────┘

-- Example usage for mini.surround:
--  * ysiw{char}             - [y]es [s]urround [i]nside [w]ord with {char}
--  * ysawt -> {tag}         - [y]es [s]urround [a]round [w]ord with [t]ag {tag}
--  * yassq                  - [y]es [s]urround [s]entence (ss = line) with [q]uotes
--  * ds{char}               - [d]elete [s]urrounding {char}
--  * cs{char}{replacement}  - [c]hange [s]urrounding {char} with {replacement}
--  * S (Visual mode)        - [S]urround current selection
Lib.later(function()
  require('mini.surround').setup({
    mappings = {
      add = 'ys',
      delete = 'ds',
      find = '',
      find_left = '',
      highlight = '',
      replace = 'cs',
      suffix_last = '',
      suffix_next = '',
    },
    search_method = 'cover',
  })

  -- S in Visual mode is a common convenience. Also delete `ys` from Visual mode (since its accompanying `ds`/`cs` don't exist in Visual mode anyway)
  vim.keymap.del('x', 'ys')
  vim.keymap.set('x', 'S', [[:<C-u>lua MiniSurround.add('visual')<CR>]], {
    desc = 'Add surrounding to selection',
    silent = true,
  })

  -- Alias the common `yss` ("yes surround sentence / line") to mini.surround's `ys_`
  vim.keymap.set('n', 'yss', 'ys_', {
    desc = 'Add surrounding to line',
    remap = true,
    silent = true,
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.pairs                                │
-- └───────────────────────────────────────────┘

-- Note: use <C-v>( to insert a literal single part of the pair
Lib.later(function()
  require('mini.pairs').setup({ modes = { command = true } })

  local function disable_minipairs_in_prose(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    if is_prose_buffer(bufnr) then vim.b[bufnr].minipairs_disable = true end
  end

  local mini_group = Lib.augroup('mini')
  Lib.autocmd('FileType', {
    group = mini_group,
    pattern = prose_filetypes,
    desc = 'Disable mini.pairs in prose buffers',
    callback = function(args) vim.b[args.buf].minipairs_disable = true end,
  })

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    disable_minipairs_in_prose(bufnr)
  end
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.indentscope                          │
-- └───────────────────────────────────────────┘

Lib.later(function()
  local indentscope = require('mini.indentscope')
  indentscope.setup({
    symbol = '│',
    draw = {
      delay = 0,
      animation = indentscope.gen_animation.linear({ duration = 125, unit = 'total' }),
    },
    options = {
      try_as_border = true,
    },
  })

  local function refresh_indentscope_disable(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    vim.b[bufnr].miniindentscope_disable = vim.bo[bufnr].buftype ~= '' or is_prose_buffer(bufnr)
  end

  Lib.autocmd({ 'FileType', 'BufWinEnter', 'TermOpen' }, {
    group = Lib.augroup('mini_indentscope'),
    desc = 'Disable mini.indentscope in prose and special buffers',
    callback = function(args) refresh_indentscope_disable(args.buf) end,
  })

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    refresh_indentscope_disable(bufnr)
  end
end)

-- ┌───────────────────────────────────────────┐
-- │ mini.cursorword                           │
-- └───────────────────────────────────────────┘

Lib.later(function() require('mini.cursorword').setup() end)

-- ┌───────────────────────────────────────────┐
-- │ mini.bufremove                            │
-- └───────────────────────────────────────────┘

Lib.later(function() require('mini.bufremove').setup() end)

vim.api.nvim_create_user_command(
  'NeocraftBufferDelete',
  function(opts) require('mini.bufremove').delete(0, opts.bang) end,
  {
    bang = true,
    desc = 'Delete current buffer with MiniBufremove',
  }
)

vim.api.nvim_create_user_command(
  'NeocraftBufferWipeout',
  function(opts) require('mini.bufremove').wipeout(0, opts.bang) end,
  {
    bang = true,
    desc = 'Wipe out current buffer with MiniBufremove',
  }
)

return M
