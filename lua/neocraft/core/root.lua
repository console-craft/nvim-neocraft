-- Neocraft project root detection module.

---@alias neocraft.root.Detector fun(buf: integer): string[]
---@alias neocraft.root.SpecEntry string|string[]|neocraft.root.Detector

---@class neocraft.root.Detected
---@field spec neocraft.root.SpecEntry
---@field paths string[]

---@class neocraft.root.DetectOpts
---@field buf? integer
---@field spec? neocraft.root.SpecEntry[]
---@field all? boolean

---@class neocraft.root.Opts
---@field buf? integer
---@field spec? neocraft.root.SpecEntry[]

local M = {}

M.project_markers =
  { '.git', 'lua', 'package.json', 'pyproject.toml', 'stylua.toml', 'go.mod', 'Cargo.toml', 'Makefile' }

M.spec = {
  'lsp',
  M.project_markers,
  'cwd',
}

-- Normalize a path to its real filesystem location when possible, following symlinks.
---@param path? string
---@return string?
function M.realpath(path)
  if path == nil or path == '' then return nil end

  return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

-- Return the current working directory with realpath normalization.
---@return string
function M.cwd()
  local cwd = vim.uv.cwd()
  if cwd == nil or cwd == '' then return vim.fs.normalize(vim.fn.getcwd()) end

  return M.realpath(cwd) or vim.fs.normalize(cwd)
end

-- Return the normalized absolute path for a buffer's file.
---@param buf? integer
---@return string?
function M.bufpath(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf

  return M.realpath(vim.api.nvim_buf_get_name(buf --[[@as integer]]))
end

local detectors = {}

-- Return the current working directory as the root candidate.
detectors.cwd = function() return { M.cwd() } end

local function is_ancestor(root, path) return path == root or vim.startswith(path, root .. '/') end

-- Collect root candidates from active LSP clients for the buffer, including workspace folders and root_dir.
detectors.lsp = function(buf)
  local bufpath = M.bufpath(buf)
  if bufpath == nil then return {} end

  local roots = {}

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    for _, workspace in ipairs(client.config.workspace_folders or client.workspace_folders or {}) do
      if workspace.uri then table.insert(roots, vim.uri_to_fname(workspace.uri)) end
    end

    table.insert(roots, client.root_dir)
    if type(client.config.root_dir) == 'string' then table.insert(roots, client.config.root_dir) end
  end

  return vim.tbl_filter(function(path)
    local normalized = M.realpath(path)
    if normalized == nil then return false end
    return is_ancestor(normalized, bufpath)
  end, roots)
end

-- Search upward from the buffer's path for any of the patterns, returning the directory containing the first match.
---@param buf integer
---@param patterns string|string[]
---@return string[]
detectors.pattern = function(buf, patterns)
  patterns = type(patterns) == 'string' and { patterns } or patterns

  local start_path = M.bufpath(buf) or M.cwd()
  if start_path == nil then return {} end
  if vim.fn.isdirectory(start_path) == 0 then start_path = vim.fs.dirname(start_path) end

  local marker = vim.fs.find(patterns, { path = start_path, upward = true })[1]
  if marker == nil then return {} end

  return { vim.fs.dirname(marker) }
end

-- Resolve a spec entry to a detector function.
---@param spec neocraft.root.SpecEntry
---@return neocraft.root.Detector
local function resolve(spec)
  if type(spec) == 'string' and detectors[spec] then return detectors[spec] end
  if type(spec) == 'function' then return spec end

  return function(buf) return detectors.pattern(buf, spec) end
end

---@param paths? string[]
---@return string[]
local function normalize_paths(paths)
  local result = {}

  for _, path in ipairs(paths or {}) do
    local normalized = M.realpath(path)
    if normalized and not vim.tbl_contains(result, normalized) then table.insert(result, normalized) end
  end

  table.sort(result, function(a, b) return #a > #b end)

  return result
end

-- Detect matching root candidates for a buffer using the given spec.
---@param opts? neocraft.root.DetectOpts
---@return neocraft.root.Detected[]
function M.detect(opts)
  opts = opts or {}
  ---@type integer
  local buf = opts.buf
  if buf == nil or buf == 0 then buf = vim.api.nvim_get_current_buf() end
  local spec = opts.spec or M.spec
  local roots = {}

  for _, entry in ipairs(spec) do
    local paths = normalize_paths(resolve(entry)(buf))

    if #paths > 0 then
      table.insert(roots, { spec = entry, paths = paths })
      if opts.all == false then break end
    end
  end

  return roots
end

local cache = {}

-- Return the preferred project root for a buffer, with caching for the default spec.
---@param opts? neocraft.root.Opts
---@return string
function M.get(opts)
  opts = opts or {}
  ---@type integer
  local buf = opts.buf
  if buf == nil or buf == 0 then buf = vim.api.nvim_get_current_buf() end

  if opts.spec ~= nil then
    local detected = M.detect({ buf = buf, spec = opts.spec, all = false })
    return detected[1] and detected[1].paths[1] or M.cwd()
  end

  if cache[buf] == nil then
    local detected = M.detect({ buf = buf, all = false })
    local first = detected[1]
    cache[buf] = first and first.paths[1] or M.cwd()
  end

  return cache[buf]
end

-- Return the nearest Git root for a buffer or detected project.
---@param opts? neocraft.root.Opts
---@return string
function M.git(opts)
  opts = opts or {}
  local root = M.get(opts)
  local marker = root and vim.fs.find('.git', { path = root, upward = true })[1] or nil

  return marker and M.realpath(vim.fs.dirname(marker)) or root or M.cwd()
end

-- Clear the cached root for a buffer, or all buffers if no buffer is specified.
local function clear(buf)
  if buf == nil then
    cache = {}
    return
  end

  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
  cache[buf] = nil
end

local group = Lib.augroup('root')

Lib.autocmd({ 'LspAttach', 'BufFilePost', 'BufWritePost' }, {
  group = group,
  desc = 'Clear Neocraft root cache for changed buffers',
  callback = function(args) clear(args.buf) end,
})

Lib.autocmd('DirChanged', {
  group = group,
  desc = 'Clear Neocraft root cache after directory changes',
  callback = function() clear() end,
})

return M
