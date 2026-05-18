local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

-- Builtin and extra picker helpers

local root = require('neocraft.core.root')

-- Resolve buffer number, treating nil and 0 as current buffer.
local function resolve_buf(buf) return (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf end

-- Determine the appropriate working directory for a picker based on the given buffer and kind.
local function pick_cwd(buf, kind)
  local resolver = kind == 'git' and root.git or root.get
  return resolver({ buf = resolve_buf(buf) })
end

-- Prepare options for starting a picker by ensuring the source.cwd is set based on the buffer and kind.
local function pick_start_opts(buf, opts, kind)
  local start_opts = vim.deepcopy(opts or {})
  start_opts.source = start_opts.source or {}
  start_opts.source.cwd = start_opts.source.cwd or pick_cwd(buf, kind)
  return start_opts
end

-- TODOs picker helpers

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

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Start a MiniPick built-in picker by name, allowing for local and start options to be specified.
function M.builtin(name, local_opts, opts)
  opts = vim.deepcopy(opts or {})

  local buf = opts.buf
  local kind = opts.kind or 'project'
  opts.buf = nil
  opts.kind = nil

  local builtin = require('mini.pick').builtin[name]
  if type(builtin) ~= 'function' then error(('Unknown MiniPick builtin: %s'):format(name)) end

  return builtin(local_opts, pick_start_opts(buf, opts, kind))
end

-- Start a MiniExtra picker by name, allowing for local and start options to be specified.
function M.extra(name, local_opts, opts)
  opts = vim.deepcopy(opts or {})

  local buf = opts.buf
  local kind = opts.kind or 'project'
  opts.buf = nil
  opts.kind = nil

  local picker = require('mini.extra').pickers[name]
  if type(picker) ~= 'function' then error(('Unknown MiniExtra picker: %s'):format(name)) end

  return picker(local_opts, pick_start_opts(buf, opts, kind))
end

-- Start 'files' built-in picker, showing files in the current project.
function M.files(buf, opts)
  opts = vim.tbl_extend('force', { buf = buf }, opts or {})
  return M.builtin('files', nil, opts)
end

-- Start 'files' built-in picker, showing files across the full Git root.
function M.all_files(buf, opts)
  opts = vim.tbl_deep_extend('force', {
    buf = buf,
    kind = 'git',
    source = { name = 'Find all files' },
  }, opts or {})

  return M.builtin('files', nil, opts)
end

-- Start 'grep_live' built-in picker, showing live grep results for the current project.
function M.grep_live(buf, opts)
  opts = vim.tbl_extend('force', { buf = buf }, opts or {})
  return M.builtin('grep_live', nil, opts)
end

-- Start 'grep_live' built-in picker, showing live grep results across the full Git root.
function M.all_grep_live(buf, opts)
  opts = vim.tbl_deep_extend('force', {
    buf = buf,
    kind = 'git',
    source = { name = 'Grep all text' },
  }, opts or {})

  return M.builtin('grep_live', nil, opts)
end

-- Start 'grep_cword' custom picker, showing grep results for the word under the cursor in the current project.
function M.grep_cword(buf, opts)
  local word = vim.fn.expand('<cword>')
  if word == '' then return M.grep_live(buf, opts) end

  local pat = '\\V\\<' .. vim.fn.escape(word, '\\') .. '\\>'
  vim.fn.setreg('/', pat)
  vim.opt.hlsearch = true

  opts = vim.tbl_extend('force', { buf = buf }, opts or {})
  return M.builtin('grep', { pattern = word }, opts)
end

-- Start 'grep_cword' custom picker, showing grep results for the word under the cursor across the full Git root.
function M.all_grep_cword(buf, opts)
  opts = vim.tbl_deep_extend('force', {
    buf = buf,
    kind = 'git',
    source = { name = 'Grep all word' },
  }, opts or {})

  return M.grep_cword(buf, opts)
end

-- Starts 'quickfix_list' custom picker, showing items in the quickfix list for all buffers.
function M.quickfix_list()
  return M.extra('list', { scope = 'quickfix' }, {
    source = { name = 'Quickfix List' },
  })
end

-- Starts 'location_list' custom picker, showing items in the location list for the current buffer.
function M.location_list()
  return M.extra('list', { scope = 'location' }, {
    source = { name = 'Location List' },
  })
end

-- Resume the most recently used picker, if any, using the built-in 'resume' picker.
function M.resume()
  local ok, result = pcall(require('mini.pick').builtin.resume)
  if ok then return result end

  vim.notify('No picker to resume', vim.log.levels.INFO)
end

-- Starts 'todos' custom picker, showing custom comment labels across all files in the current project.
function M.todos(buf, opts)
  opts = vim.tbl_deep_extend('force', {
    buf = buf,
    source = {
      name = 'TODOs',
      preview = todos_preview,
      show = todos_show,
    },
  }, opts or {})

  return M.builtin('grep', {
    pattern = [[\b(ERROR|DANGER|CRITICAL|FAIL|BUG|FIXME|WARNING|CAUTION|IMPORTANT|WARN|DEPRECATED|WIP|TEMP|TEMPORARY|TODO|SKIP|PATCH|XXX|INFO|HINT|NOTE|TIP|EXAMPLE|DOCS)\b]],
  }, opts)
end

-- Starts 'todos' custom picker, showing custom comment labels across the full Git root.
function M.all_todos(buf, opts)
  opts = vim.tbl_deep_extend('force', {
    buf = buf,
    kind = 'git',
    source = { name = 'All TODOs' },
  }, opts or {})

  return M.todos(buf, opts)
end

return M
