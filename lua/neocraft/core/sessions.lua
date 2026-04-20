-- Automatically load and save sessions on startup and exit by managing session files associated with project roots.

local M = {}

local root = require('neocraft.core.root')

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local function dir() return vim.fs.joinpath(vim.fn.stdpath('state'), 'sessions') end

-- Return the project root path for a buffer, or nil if no root is found.
local function root_path(buf)
  local session_root = root.get({ buf = buf })
  return session_root and root.realpath(session_root) or nil
end

-- Generate a session name based on the project root path, or return nil if no root is found.
local function name(session_root)
  session_root = session_root or root_path()
  if not session_root or session_root == '' then return nil end

  return (session_root:gsub('[^%w%.%-_]+', '_')) .. '.vim'
end

-- Return the full path to the session file for a project root, or nil if no root is found.
local function path(session_root)
  local session_name = name(session_root)
  return session_name and vim.fs.joinpath(dir(), session_name) or nil
end

-- Check if a session file exists for a project root.
local function exists(session_root)
  local session_path = path(session_root)
  return session_path ~= nil and vim.uv.fs_stat(session_path) ~= nil
end

-- Write the current session for the project root, creating or overwriting the session file as needed.
local function write_current(opts)
  local session_name = name()
  if session_name == nil then return false end

  opts = vim.tbl_extend('force', { force = true, verbose = false }, opts or {})
  require('mini.sessions').write(session_name, opts)
  return true
end

-- Read the session for the current project root, if it exists, and restore the session state.
local function read_current(opts)
  local session_name = name()
  if session_name == nil or not exists() then return false end

  opts = vim.tbl_extend('force', { verbose = false }, opts or {})
  require('mini.sessions').read(session_name, opts)
  return true
end

-- Attempt to read the session for the current project root on startup, if no files were specified on the command line.
local function maybe_autoread()
  if vim.fn.argc(-1) > 0 then return false end
  return pcall(read_current)
end

local discard_key = 'neocraft_discard_session'

-- ┌───────────────────────────────────────────┐
-- │ Auto load & auto save sessions            │
-- └───────────────────────────────────────────┘

local group = Lib.augroup('sessions')

Lib.autocmd('VimEnter', {
  group = group,
  desc = 'Restore Neocraft project session on bare startup',
  callback = function() pcall(maybe_autoread) end,
})

Lib.autocmd('VimLeavePre', {
  group = group,
  desc = 'Write Neocraft project session on exit',
  callback = function()
    if vim.g[discard_key] then
      vim.g[discard_key] = nil
      return
    end

    pcall(write_current)
  end,
})

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Delete the session file for the current project root, if it exists.
function M.delete_current(opts)
  local session_name = name()
  if session_name == nil then return false end
  if not exists() then
    vim.notify('No session file to remove for this project', vim.log.levels.INFO)
    return false
  end

  opts = vim.tbl_extend('force', { force = true, verbose = true }, opts or {})
  require('mini.sessions').delete(session_name, opts)
  return true
end

-- Set a flag to skip saving the session on exit, which can be used to discard the session when exiting Neovim.
function M.discard_once() vim.g[discard_key] = true end

return M
