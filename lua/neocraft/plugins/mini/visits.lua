-- Configure mini.visits and Neocraft's project visit tracking.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local root = require('neocraft.core.root')

local track_delay = 1000
local track_tick = 0
local last_visit = nil

local function resolve_buf(buf) return (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf end

local function current_path(buf) return root.bufpath(resolve_buf(buf)) end

local function has_file_context(buf)
  buf = resolve_buf(buf)
  return vim.bo[buf].buftype == '' and current_path(buf) ~= nil
end

local function current_root(buf)
  local cwd = root.get({ buf = resolve_buf(buf) })
  return cwd and root.realpath(cwd) or nil
end

local function register_current(buf)
  buf = resolve_buf(buf)
  if not has_file_context(buf) then return false end

  local path = current_path(buf)
  local cwd = current_root(buf)
  if path == nil or cwd == nil then return false end

  if last_visit and last_visit.path == path and last_visit.cwd == cwd then return false end

  require('mini.visits').register_visit(path, cwd)
  last_visit = { path = path, cwd = cwd }
  return true
end

-- ┌───────────────────────────────────────────┐
-- │ Setup Mini Visits                         │
-- └───────────────────────────────────────────┘

Lib.later(
  function()
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
  end
)

Lib.autocmd('BufEnter', {
  group = Lib.augroup('visits'),
  desc = 'Track project visits for settled file buffers',
  callback = function(args)
    track_tick = track_tick + 1
    local tick = track_tick
    local buf = args.buf

    vim.defer_fn(function()
      if tick ~= track_tick then return end
      if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_get_current_buf() ~= buf then return end
      register_current(buf)
    end, track_delay)
  end,
})

return M
