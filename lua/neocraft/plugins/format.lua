local pack = require('neocraft.core.pack')
local lang = require('neocraft.lang')
local root = require('neocraft.core.root')

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local prettier_markers = {
  '.prettierrc',
  '.prettierrc.json',
  '.prettierrc.yml',
  '.prettierrc.yaml',
  '.prettierrc.json5',
  '.prettierrc.js',
  '.prettierrc.cjs',
  '.prettierrc.mjs',
  '.prettierrc.toml',
  'prettier.config.js',
  'prettier.config.cjs',
  'prettier.config.mjs',
}

local oxfmt_markers = {
  '.oxfmtrc.json',
  '.oxfmtrc.jsonc',
}

local biome_markers = {
  'biome.json',
  'biome.jsonc',
  '.biome.json',
  '.biome.jsonc',
}

local ruff_markers = {
  'ruff.toml',
  '.ruff.toml',
  'pyproject.toml',
}

local family_order = { 'prettier', 'oxfmt', 'biome', 'ruff' }

local family_support = {
  prettier = {
    javascript = true,
    javascriptreact = true,
    json = true,
    jsonc = true,
    markdown = true,
    toml = true,
    typescript = true,
    typescriptreact = true,
    yaml = true,
    ['yaml.docker-compose'] = true,
  },
  oxfmt = {
    javascript = true,
    javascriptreact = true,
    json = true,
    jsonc = true,
    markdown = true,
    toml = true,
    typescript = true,
    typescriptreact = true,
    yaml = true,
    ['yaml.docker-compose'] = true,
  },
  biome = {
    javascript = true,
    javascriptreact = true,
    json = true,
    jsonc = true,
    typescript = true,
    typescriptreact = true,
  },
  ruff = {
    python = true,
  },
}

local function file_exists(path)
  local stat = path and vim.uv.fs_stat(path) or nil
  return stat and stat.type == 'file'
end

local function read_json(path)
  local file = io.open(path, 'r')
  if not file then return nil end

  local content = file:read('*all')
  file:close()

  local ok, decoded = pcall(vim.json.decode, content)
  return ok and decoded or nil
end

local function read_text(path)
  local file = io.open(path, 'r')
  if not file then return nil end

  local content = file:read('*all')
  file:close()

  return content
end

local function package_has_prettier(dir)
  local package_json = vim.fs.joinpath(dir, 'package.json')
  if not file_exists(package_json) then return false end

  local decoded = read_json(package_json)
  return type(decoded) == 'table' and decoded.prettier ~= nil
end

local function family_markers(family)
  if family == 'prettier' then return prettier_markers end
  if family == 'oxfmt' then return oxfmt_markers end
  if family == 'biome' then return biome_markers end
  if family == 'ruff' then return ruff_markers end
  return {}
end

local function ruff_file_has_format_config(path)
  local content = read_text(path)
  if type(content) ~= 'string' then return false end

  for _, line in ipairs(vim.split(content, '\n', { plain = true })) do
    if line:match('^%s*%[format%]%s*$') then return true end
  end

  return false
end

local function pyproject_has_ruff_format(dir)
  local pyproject = vim.fs.joinpath(dir, 'pyproject.toml')
  local content = read_text(pyproject)
  if type(content) ~= 'string' then return false end

  for _, line in ipairs(vim.split(content, '\n', { plain = true })) do
    if line:match('^%s*%[tool%.ruff%.format%]%s*$') then return true end
  end

  return false
end

local function family_has_config(dir, family)
  if family == 'ruff' then
    if ruff_file_has_format_config(vim.fs.joinpath(dir, 'ruff.toml')) then return true end
    if ruff_file_has_format_config(vim.fs.joinpath(dir, '.ruff.toml')) then return true end
    return pyproject_has_ruff_format(dir)
  end

  for _, marker in ipairs(family_markers(family)) do
    if file_exists(vim.fs.joinpath(dir, marker)) then return true end
  end

  return family == 'prettier' and package_has_prettier(dir)
end

local function start_dir(bufnr)
  local path = root.bufpath(bufnr) or root.get({ buf = bufnr }) or root.cwd()
  local normalized = root.realpath(path) or vim.fs.normalize(path)
  if vim.fn.isdirectory(normalized) == 1 then return normalized end
  return vim.fs.dirname(normalized)
end

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

local function project_formatter_family(bufnr, filetype)
  local family = search_project(bufnr, function(dir)
    for _, name in ipairs(family_order) do
      if family_support[name][filetype] and family_has_config(dir, name) then return name end
    end
  end)

  return family
end

local function formatter_root(bufnr, family)
  local matched_dir = select(
    2,
    search_project(bufnr, function(dir)
      if family_has_config(dir, family) then return true end
    end)
  )

  return matched_dir
end

local function project_formatters(bufnr, filetype)
  local family = project_formatter_family(bufnr, filetype)
  if family == 'prettier' then return { 'project_prettierd', 'project_prettier', stop_after_first = true } end
  if family == 'oxfmt' then return { 'project_oxfmt' } end
  if family == 'biome' then return { 'project_biome' } end
  if family == 'ruff' then return { 'project_ruff_organize_imports', 'project_ruff_format' } end
end

local function project_formatters_or_empty(bufnr, filetype) return project_formatters(bufnr, filetype) or {} end

local function resolve_formatters(entry)
  if vim.islist(entry) then return vim.deepcopy(entry) end

  return function(bufnr)
    local formatters = type(entry.project) == 'string' and project_formatters_or_empty(bufnr, entry.project) or {}
    if #formatters > 0 then return formatters end
    if vim.islist(entry.fallback) then return vim.deepcopy(entry.fallback) end
    return {}
  end
end

local function formatters_by_ft()
  local resolved = {}

  for filetype, entry in pairs(lang.formatters_by_ft) do
    resolved[filetype] = resolve_formatters(entry)
  end

  return resolved
end

local function format_on_save(bufnr)
  if vim.g.enable_format_on_save ~= true then return nil end
  if vim.bo[bufnr].buftype ~= '' then return nil end

  local disabled = {
    gitcommit = true,
    markdown = true,
    text = true,
  }

  if disabled[vim.bo[bufnr].filetype] then return nil end

  return {
    timeout_ms = 3000,
    lsp_format = 'fallback',
  }
end

-- ┌───────────────────────────────────────────┐
-- │ Conform setup                             │
-- └───────────────────────────────────────────┘

pack.add('format', {
  { src = 'https://github.com/stevearc/conform.nvim' },
})

Lib.now(function()
  require('conform').setup({
    default_format_opts = {
      lsp_format = 'fallback',
      timeout_ms = 3000,
    },
    format_on_save = format_on_save,
    notify_on_error = true,
    formatters = {
      project_prettierd = {
        inherit = 'prettierd',
        cwd = function(_, ctx) return formatter_root(ctx.buf, 'prettier') end,
        require_cwd = true,
      },
      project_prettier = {
        inherit = 'prettier',
        cwd = function(_, ctx) return formatter_root(ctx.buf, 'prettier') end,
        require_cwd = true,
      },
      project_oxfmt = {
        inherit = 'oxfmt',
        cwd = function(_, ctx) return formatter_root(ctx.buf, 'oxfmt') end,
        require_cwd = true,
      },
      project_biome = {
        inherit = 'biome',
        cwd = function(_, ctx) return formatter_root(ctx.buf, 'biome') end,
        require_cwd = true,
      },
      project_ruff_organize_imports = {
        inherit = 'ruff_organize_imports',
        cwd = function(_, ctx) return formatter_root(ctx.buf, 'ruff') end,
        require_cwd = true,
      },
      project_ruff_format = {
        inherit = 'ruff_format',
        cwd = function(_, ctx) return formatter_root(ctx.buf, 'ruff') end,
        require_cwd = true,
      },
    },
    formatters_by_ft = formatters_by_ft(),
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ Conform commands                          │
-- └───────────────────────────────────────────┘

local function with_conform(callback)
  local ok, conform = pcall(require, 'conform')
  if not ok then
    vim.notify('conform.nvim is not available', vim.log.levels.ERROR)
    return
  end

  callback(conform)
end

function M.format(opts)
  with_conform(
    function(conform)
      conform.format(vim.tbl_deep_extend('force', {
        async = false,
        lsp_format = 'fallback',
        timeout_ms = 3000,
      }, opts or {}))
    end
  )
end

function M.info()
  with_conform(function() vim.cmd('ConformInfo') end)
end

function M.formatexpr()
  local ok, conform = pcall(require, 'conform')
  if not ok then return 1 end
  return conform.formatexpr()
end

return M
