local M = {}

M.spec = {
  'lsp',
  { '.git', 'lua', 'package.json', 'pyproject.toml', 'stylua.toml', 'go.mod', 'Cargo.toml', 'Makefile' },
  'cwd',
}

M.cache = {}
M.detectors = {}

function M.realpath(path)
  if path == nil or path == '' then return nil end

  return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

function M.cwd() return M.realpath(vim.uv.cwd()) or vim.fs.normalize(vim.uv.cwd()) end

function M.bufpath(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf

  return M.realpath(vim.api.nvim_buf_get_name(buf))
end

local function normalize_paths(paths)
  local result = {}

  for _, path in ipairs(paths or {}) do
    local normalized = M.realpath(path)
    if normalized and not vim.tbl_contains(result, normalized) then table.insert(result, normalized) end
  end

  table.sort(result, function(a, b) return #a > #b end)

  return result
end

local function is_ancestor(root, path) return path == root or vim.startswith(path, root .. '/') end

M.detectors.cwd = function() return { M.cwd() } end

M.detectors.lsp = function(buf)
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
    return normalized and is_ancestor(normalized, bufpath)
  end, roots)
end

M.detectors.pattern = function(buf, patterns)
  patterns = type(patterns) == 'string' and { patterns } or patterns

  local start_path = M.bufpath(buf) or M.cwd()
  if start_path == nil then return {} end
  if vim.fn.isdirectory(start_path) == 0 then start_path = vim.fs.dirname(start_path) end

  local marker = vim.fs.find(patterns, { path = start_path, upward = true })[1]
  if marker == nil then return {} end

  return { vim.fs.dirname(marker) }
end

function M.resolve(spec)
  if type(spec) == 'string' and M.detectors[spec] then return M.detectors[spec] end
  if type(spec) == 'function' then return spec end

  return function(buf) return M.detectors.pattern(buf, spec) end
end

function M.detect(opts)
  opts = opts or {}
  local buf = (opts.buf == nil or opts.buf == 0) and vim.api.nvim_get_current_buf() or opts.buf
  local spec = opts.spec or M.spec
  local roots = {}

  for _, entry in ipairs(spec) do
    local paths = normalize_paths(M.resolve(entry)(buf))

    if #paths > 0 then
      table.insert(roots, { spec = entry, paths = paths })
      if opts.all == false then break end
    end
  end

  return roots
end

function M.clear(buf)
  if buf == nil then
    M.cache = {}
    return
  end

  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
  M.cache[buf] = nil
end

function M.get(opts)
  opts = opts or {}
  local buf = (opts.buf == nil or opts.buf == 0) and vim.api.nvim_get_current_buf() or opts.buf

  if opts.spec ~= nil then
    local detected = M.detect({ buf = buf, spec = opts.spec, all = false })
    return detected[1] and detected[1].paths[1] or M.cwd()
  end

  if M.cache[buf] == nil then
    local detected = M.detect({ buf = buf, all = false })
    M.cache[buf] = detected[1] and detected[1].paths[1] or M.cwd()
  end

  return M.cache[buf]
end

function M.git(opts)
  opts = opts or {}
  local root = M.get(opts)
  local marker = root and vim.fs.find('.git', { path = root, upward = true })[1] or nil

  return marker and M.realpath(vim.fs.dirname(marker)) or root or M.cwd()
end

local group = Lib.augroup('root')

Lib.autocmd({ 'LspAttach', 'BufFilePost', 'BufWritePost' }, {
  group = group,
  desc = 'Clear Neocraft root cache for changed buffers',
  callback = function(args) M.clear(args.buf) end,
})

Lib.autocmd('DirChanged', {
  group = group,
  desc = 'Clear Neocraft root cache after directory changes',
  callback = function() M.clear() end,
})

return M
