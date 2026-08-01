-- Resolve explicitly configured SonarLint projects from Git repository metadata.

---@class neocraft.sonarlint.ProjectSpec
---@field remotes string[]
---@field path string
---@field connection_id string
---@field project_key string
---@field mode? 'auto'|'local'

---@class neocraft.sonarlint.GitMetadata
---@field common_dir string
---@field current_root string
---@field main_root string
---@field remote string

---@class neocraft.sonarlint.Project
---@field common_dir string
---@field current_root string
---@field main_root string
---@field remote string
---@field root_dir string
---@field connection_id string
---@field project_key string
---@field mode 'auto'|'local'

local M = {}

local root = require('neocraft.core.root')

local metadata_cache = {}

-- Normalize common SSH and HTTP Git remote forms to a stable host/repository identity.
local function normalize_remote(remote)
  if type(remote) ~= 'string' then return nil end

  remote = vim.trim(remote)
  if remote == '' then return nil end

  local host, path = remote:match('^[^@]+@([^:]+):(.+)$')
  if host == nil then
    host, path = remote:match('^ssh://[^@]+@([^/]+)/(.+)$')
  end
  if host == nil then
    host, path = remote:match('^https?://([^/]+)/(.+)$')
  end
  if host == nil or path == nil then return remote:gsub('/+$', ''):gsub('%.git$', '') end

  return host:lower() .. '/' .. path:gsub('/+$', ''):gsub('%.git$', '')
end

local function path_is_within(path, parent) return path == parent or vim.startswith(path, parent .. '/') end

local function normalized_project_path(path)
  path = vim.fs.normalize(path or ''):gsub('^/+', ''):gsub('/+$', '')
  return path == '.' and '' or path
end

local function remote_matches(remote, candidates)
  remote = normalize_remote(remote)
  if remote == nil then return false end

  return vim.iter(candidates):any(function(candidate) return normalize_remote(candidate) == remote end)
end

local function run_git(cwd, args)
  local command = vim.list_extend({ 'git', '-C', cwd }, args)
  local result = vim.system(command, { text = true }):wait()
  if result.code ~= 0 then return nil end

  local output = vim.trim(result.stdout or '')
  return output ~= '' and output or nil
end

-- Return worktree-aware Git metadata for a file path.
local function git_metadata(path)
  local start = vim.fs.dirname(path)
  local marker = vim.fs.find('.git', { path = start, upward = true })[1]
  if marker == nil then return nil end

  local checkout_root = root.realpath(vim.fs.dirname(marker))
  if checkout_root == nil then return nil end
  if metadata_cache[checkout_root] ~= nil then return metadata_cache[checkout_root] end

  local output =
    run_git(checkout_root, { 'rev-parse', '--path-format=absolute', '--git-common-dir', '--show-toplevel' })
  if output == nil then return nil end

  local lines = vim.split(output, '\n', { trimempty = true })
  local common_dir = root.realpath(lines[1])
  local current_root = root.realpath(lines[2])
  local remote = current_root and run_git(current_root, { 'remote', 'get-url', 'origin' }) or nil
  local main_root = common_dir and root.realpath(vim.fs.dirname(common_dir)) or nil
  if common_dir == nil or current_root == nil or main_root == nil or remote == nil then return nil end

  ---@type neocraft.sonarlint.GitMetadata
  local metadata = {
    common_dir = common_dir,
    current_root = current_root,
    main_root = main_root,
    remote = remote,
  }
  metadata_cache[checkout_root] = metadata
  return metadata
end

-- Select the most specific configured project containing a file.
---@param metadata neocraft.sonarlint.GitMetadata
---@param path string
---@param specs neocraft.sonarlint.ProjectSpec[]
---@return neocraft.sonarlint.Project?
function M.select(metadata, path, specs)
  local normalized_path = root.realpath(path)
  local current_root = root.realpath(metadata.current_root)
  if normalized_path == nil or current_root == nil or not path_is_within(normalized_path, current_root) then
    return nil
  end

  local selected, selected_length
  for _, spec in ipairs(specs) do
    if remote_matches(metadata.remote, spec.remotes) then
      local relative_path = normalized_project_path(spec.path)
      local root_dir = relative_path == '' and current_root or vim.fs.joinpath(current_root, relative_path)

      if path_is_within(normalized_path, root_dir) and (selected_length == nil or #root_dir > selected_length) then
        local mode = spec.mode or 'auto'
        if mode ~= 'auto' and mode ~= 'local' then error('Invalid SonarLint project mode: ' .. mode) end

        selected_length = #root_dir
        selected = {
          common_dir = metadata.common_dir,
          current_root = current_root,
          main_root = metadata.main_root,
          remote = normalize_remote(metadata.remote),
          root_dir = root_dir,
          connection_id = spec.connection_id,
          project_key = spec.project_key,
          mode = mode,
        }
      end
    end
  end

  return selected
end

-- Resolve the configured SonarLint project for a buffer without starting a client.
---@param specs neocraft.sonarlint.ProjectSpec[]
---@param bufnr? integer
---@return neocraft.sonarlint.Project?
function M.resolve(specs, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local path = root.bufpath(bufnr)
  if path == nil then return nil end

  local metadata = git_metadata(path)
  return metadata and M.select(metadata, path, specs) or nil
end

return M
