---@class neocraft.formatting.Opts
---@field formatter_order string[]
---@field formatter_support table<string, table<string, boolean>>
---@field markers_by_formatter table<string, string[]>

---@alias neocraft.formatting.ResolvedFormatters string[]|fun(bufnr: integer): string[]

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local root = require('neocraft.core.root')

-- Checks if a file exists at the given path.
local function file_exists(path)
  local stat = path and vim.uv.fs_stat(path) or nil
  return stat and stat.type == 'file'
end

-- Reads and decodes a JSON file at the given path returning the decoded table or nil on failure.
local function read_json(path)
  local file = io.open(path, 'r')
  if not file then return nil end

  local content = file:read('*all')
  file:close()

  local ok, decoded = pcall(vim.json.decode, content)
  return ok and decoded or nil
end

-- Reads the entire content of a text file at the given path returning it as a string or nil on failure.
local function read_text(path)
  local file = io.open(path, 'r')
  if not file then return nil end

  local content = file:read('*all')
  file:close()

  return content
end

-- Checks if a package.json file exists in the given directory and contains a "prettier" field.
local function package_has_prettier(dir)
  local package_json = vim.fs.joinpath(dir, 'package.json')
  if not file_exists(package_json) then return false end

  local decoded = read_json(package_json)
  return type(decoded) == 'table' and decoded.prettier ~= nil
end

-- Checks if a ruff configuration file at the given path contains a [format] section.
local function ruff_file_has_format_config(path)
  local content = read_text(path)
  if type(content) ~= 'string' then return false end

  for _, line in ipairs(vim.split(content, '\n', { plain = true })) do
    if line:match('^%s*%[format%]%s*$') then return true end
  end

  return false
end

-- Checks if a pyproject.toml file at the given path contains a [tool.ruff.format] section.
local function pyproject_has_ruff_format(dir)
  local pyproject = vim.fs.joinpath(dir, 'pyproject.toml')
  local content = read_text(pyproject)
  if type(content) ~= 'string' then return false end

  for _, line in ipairs(vim.split(content, '\n', { plain = true })) do
    if line:match('^%s*%[tool%.ruff%.format%]%s*$') then return true end
  end

  return false
end

-- Checks if the given directory contains configuration files for the specified formatter.
---@param dir string
---@param formatter string
---@param opts neocraft.formatting.Opts
---@return boolean
local function formatter_has_config(dir, formatter, opts)
  if formatter == 'ruff' then
    if ruff_file_has_format_config(vim.fs.joinpath(dir, 'ruff.toml')) then return true end
    if ruff_file_has_format_config(vim.fs.joinpath(dir, '.ruff.toml')) then return true end
    return pyproject_has_ruff_format(dir)
  end

  for _, marker in ipairs(opts.markers_by_formatter[formatter] or {}) do
    if file_exists(vim.fs.joinpath(dir, marker)) then return true end
  end

  return formatter == 'prettier' and package_has_prettier(dir)
end

-- Determines the starting directory for project root searching based on the buffer's path or current working directory.
local function start_dir(bufnr)
  local path = root.bufpath(bufnr) or root.get({ buf = bufnr }) or root.cwd()
  local normalized = root.realpath(path) or vim.fs.normalize(path)
  if vim.fn.isdirectory(normalized) == 1 then return normalized end
  return vim.fs.dirname(normalized)
end

-- Searches up the tree from the starting directory for a project root that satisfies the given callback condition.
---@generic T
---@param bufnr integer
---@param callback fun(dir: string): T?
---@return T? result
---@return string? dir
local function search_project(bufnr, callback)
  local dir = start_dir(bufnr)
  local project_root = root.realpath(root.get({ buf = bufnr })) or root.get({ buf = bufnr })

  while dir do
    local result = callback(dir)
    if result ~= nil then return result, dir end
    if dir == project_root then break end

    local parent = vim.fs.dirname(dir)
    if not parent or parent == dir then break end
    if project_root and parent ~= project_root and not vim.startswith(parent, project_root .. '/') then break end

    dir = parent
  end
end

-- Determines the formatter for the given buffer and filetype by searching for configuration files up the tree.
local function project_formatter(bufnr, filetype, opts)
  local formatter = search_project(bufnr, function(dir)
    for _, name in ipairs(opts.formatter_order) do
      if opts.formatter_support[name][filetype] and formatter_has_config(dir, name, opts) then return name end
    end
  end)

  return formatter
end

-- Determines the list of project-aware formatters for the given buffer and filetype based on found configuration files.
local function project_formatters(bufnr, filetype, opts)
  local formatter = project_formatter(bufnr, filetype, opts)
  if formatter == 'prettier' then return { 'project_prettierd', 'project_prettier', stop_after_first = true } end
  if formatter == 'oxfmt' then return { 'project_oxfmt' } end
  if formatter == 'biome' then return { 'project_biome' } end
  if formatter == 'ruff' then return { 'project_ruff_organize_imports', 'project_ruff_format' } end
end

-- Returns the list of project-aware formatters for the given buffer and filetype or an empty list if none are found.
local function project_formatters_or_empty(bufnr, filetype, opts) return project_formatters(bufnr, filetype, opts) or {} end

-- Resolves the formatter entry for a filetype to either a static list or a function that determines them at runtime.
---@param entry neocraft.lang.FormatterEntry
---@param opts neocraft.formatting.Opts
---@return neocraft.formatting.ResolvedFormatters
local function resolve_formatters(entry, opts)
  if vim.islist(entry) then return vim.deepcopy(entry) end

  return function(bufnr)
    local formatters = type(entry.project) == 'string' and project_formatters_or_empty(bufnr, entry.project, opts) or {}
    if #formatters > 0 then return formatters end
    if vim.islist(entry.fallback) then return vim.deepcopy(entry.fallback) or {} end
    return {}
  end
end
local native_fallback_filetypes = {
  gitcommit = true,
  text = true,
}

-- Safely require conform and execute the provided callback with it.
local function with_conform(callback)
  local ok, conform = pcall(require, 'conform')
  if not ok then
    vim.notify('conform.nvim is not available', vim.log.levels.ERROR)
    return
  end

  callback(conform)
end

-- Return true when Conform or LSP formatting would handle the buffer.
local function has_formatter_or_lsp(conform, bufnr)
  local formatters, lsp = conform.list_formatters_to_run(bufnr)
  return #formatters > 0 or lsp == true
end

-- Fall back to built-in `gq` only for prose-like buffers that opt out of formatexpr.
local function should_use_native_fallback(bufnr)
  local filetype = vim.bo[bufnr].filetype
  if not native_fallback_filetypes[filetype] then return false end
  if vim.bo[bufnr].formatexpr ~= '' then return false end
  return vim.bo[bufnr].textwidth > 0
end

-- Format the full buffer with native `gq` while preserving the current view.
local function native_format_buffer(bufnr)
  local winid = vim.fn.bufwinid(bufnr)
  if winid == -1 then return end

  local view = vim.api.nvim_win_call(winid, vim.fn.winsaveview)
  vim.api.nvim_win_call(winid, function() vim.cmd('silent keepjumps normal! gggqG') end)
  vim.api.nvim_win_call(winid, function() vim.fn.winrestview(view) end)
end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

---@param opts? table
function M.format(opts)
  with_conform(function(conform)
    local format_opts = vim.tbl_deep_extend('force', {
      async = false,
      lsp_format = 'fallback',
      timeout_ms = 3000,
    }, opts or {})

    -- Enable manually-triggered formatting of text and gitcommit buffers using as a fallback native Neovim formatting.
    local bufnr = format_opts.bufnr or vim.api.nvim_get_current_buf()
    if not has_formatter_or_lsp(conform, bufnr) and format_opts.range == nil and should_use_native_fallback(bufnr) then
      native_format_buffer(bufnr)
      return
    end

    conform.format(format_opts)
  end)
end

function M.info()
  with_conform(function() vim.cmd('ConformInfo') end)
end

---@return integer
function M.formatexpr()
  local ok, conform = pcall(require, 'conform')
  if not ok then return 1 end
  return conform.formatexpr()
end

-- Returns a table that maps filetypes to either static formatter lists or functions that determine them at runtime.
---@param entries table<string, neocraft.lang.FormatterEntry>
---@param opts neocraft.formatting.Opts
---@return table<string, neocraft.formatting.ResolvedFormatters>
function M.get_formatters_by_ft(entries, opts)
  local resolved = {}

  for filetype, entry in pairs(entries) do
    resolved[filetype] = resolve_formatters(entry, opts)
  end

  return resolved
end

-- Finds the project root directory for the given buffer and formatter by searching for config files up the tree.
---@param bufnr integer
---@param formatter string
---@param opts neocraft.formatting.Opts
---@return string?
function M.get_formatter_root(bufnr, formatter, opts)
  local matched_dir = select(
    2,
    search_project(bufnr, function(dir)
      if formatter_has_config(dir, formatter, opts) then return true end
    end)
  )

  return matched_dir
end

return M
