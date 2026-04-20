local M = {}

-- mini.files

local root = require('neocraft.core.root')

-- Resolve buffer number, treating nil and 0 as current buffer.
local function resolve_buf(buf) return (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf end

-- Get the real path of the given file system entry, resolving any symbolic links.
local function realpath(path) return root.realpath(path) end

-- Check if the given path exists and return its type (e.g., 'file', 'directory').
local function path_type(path)
  local stat = path and vim.uv.fs_stat(path) or nil
  return stat and stat.type or nil
end

-- Determine the appropriate anchor path for the mini.files explorer based on the given buffer.
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

function M.explore_files(buf)
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

function M.toggle_map() require('mini.map').toggle() end

return M
