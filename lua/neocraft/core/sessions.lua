local root = require('neocraft.core.root')

local M = {}

function M.dir() return vim.fs.joinpath(vim.fn.stdpath('state'), 'sessions') end

function M.root_path(buf)
  local session_root = root.get({ buf = buf })
  return session_root and root.realpath(session_root) or nil
end

function M.name(session_root)
  session_root = session_root or M.root_path()
  if not session_root or session_root == '' then return nil end

  return (session_root:gsub('[^%w%.%-_]+', '_')) .. '.vim'
end

function M.path(session_root)
  local name = M.name(session_root)
  return name and vim.fs.joinpath(M.dir(), name) or nil
end

function M.exists(session_root)
  local path = M.path(session_root)
  return path ~= nil and vim.uv.fs_stat(path) ~= nil
end

function M.read_current(opts)
  local name = M.name()
  if name == nil or not M.exists() then return false end

  opts = vim.tbl_extend('force', { verbose = false }, opts or {})
  require('mini.sessions').read(name, opts)
  return true
end

function M.write_current(opts)
  local name = M.name()
  if name == nil then return false end

  opts = vim.tbl_extend('force', { force = true, verbose = false }, opts or {})
  require('mini.sessions').write(name, opts)
  return true
end

function M.delete_current(opts)
  local name = M.name()
  if name == nil then return false end
  if not M.exists() then
    vim.notify('No session file to remove for this project', vim.log.levels.INFO)
    return false
  end

  opts = vim.tbl_extend('force', { force = true, verbose = true }, opts or {})
  require('mini.sessions').delete(name, opts)
  return true
end

local discard_key = 'neocraft_discard_session'

function M.discard_once() vim.g[discard_key] = true end

function M.maybe_autoread()
  if vim.fn.argc(-1) > 0 then return false end
  return pcall(M.read_current)
end

local group = Lib.augroup('sessions')

Lib.autocmd('VimEnter', {
  group = group,
  desc = 'Restore Neocraft project session on bare startup',
  callback = function() pcall(M.maybe_autoread) end,
})

Lib.autocmd('VimLeavePre', {
  group = group,
  desc = 'Write Neocraft project session on exit',
  callback = function()
    if vim.g[discard_key] then
      vim.g[discard_key] = nil
      return
    end

    pcall(M.write_current)
  end,
})

return M
