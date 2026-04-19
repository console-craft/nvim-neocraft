local root = require('neocraft.core.root')

local M = {}

local function fallback_label(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= '' then return vim.fs.basename(name) end

  local filetype = vim.bo[bufnr].filetype
  if filetype ~= '' then return '    󰈔  [' .. filetype .. ']' end

  return '    󰈔  [No Name]'
end

local function relative_to_root(path, root_dir)
  if path == root_dir then return vim.fs.basename(path) end
  if vim.startswith(path, root_dir .. '/') then return path:sub(#root_dir + 2) end
  return nil
end

function M.render()
  local bufnr = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == '' then return fallback_label(bufnr) end

  local root_dir = root.get({ buf = bufnr })
  local root_name = root_dir and vim.fs.basename(root_dir) or nil
  local relative = root_dir and relative_to_root(path, root_dir) or nil

  if root_name and relative and relative ~= '' then return '    󰈔  [' .. root_name .. '] → ' .. relative end
  if root_name then return '    󰈔  [' .. root_name .. '] → ' .. vim.fs.basename(path) end

  return fallback_label(bufnr)
end

return M
