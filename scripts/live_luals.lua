local client_name = 'lua_ls'
local config_root = vim.fn.stdpath('config')
local severity_names = {
  [vim.diagnostic.severity.ERROR] = 'ERROR',
  [vim.diagnostic.severity.WARN] = 'WARN',
  [vim.diagnostic.severity.INFO] = 'INFO',
  [vim.diagnostic.severity.HINT] = 'HINT',
}

local published = {}
local group = vim.api.nvim_create_augroup('neocraft_live_luals', { clear = true })

vim.api.nvim_create_autocmd('DiagnosticChanged', {
  group = group,
  callback = function(args)
    published[args.buf] = true
  end,
})

local function relative_path(path)
  return vim.fs.relpath(config_root, path) or path
end

local function collect_lua_files(dir, files)
  for name, file_type in vim.fs.dir(dir) do
    local path = vim.fs.joinpath(dir, name)

    if file_type == 'directory' then
      collect_lua_files(path, files)
    elseif file_type == 'file' and name:sub(-4) == '.lua' then
      table.insert(files, path)
    end
  end
end

local function default_paths()
  local files = {}
  local init_path = vim.fs.joinpath(config_root, 'init.lua')

  if vim.uv.fs_stat(init_path) ~= nil then table.insert(files, init_path) end

  for _, dir_name in ipairs({ 'lua', 'after' }) do
    local dir = vim.fs.joinpath(config_root, dir_name)
    if vim.uv.fs_stat(dir) ~= nil then collect_lua_files(dir, files) end
  end

  table.sort(files)
  return files
end

local function sort_diagnostics(diagnostics)
  table.sort(diagnostics, function(a, b)
    if a.lnum == b.lnum then
      if a.col == b.col then return (a.severity or 0) < (b.severity or 0) end
      return a.col < b.col
    end

    return a.lnum < b.lnum
  end)
end

local function unique_diagnostics(diagnostics)
  local unique = {}
  local seen = {}

  for _, diagnostic in ipairs(diagnostics) do
    local key = table.concat({
      diagnostic.namespace or '',
      diagnostic.lnum or '',
      diagnostic.col or '',
      diagnostic.severity or '',
      diagnostic.code or '',
      diagnostic.message or '',
    }, ':')

    if not seen[key] then
      seen[key] = true
      table.insert(unique, diagnostic)
    end
  end

  sort_diagnostics(unique)
  return unique
end

local function wait_for_client(bufnr, timeout)
  return vim.wait(timeout, function()
    return #vim.lsp.get_clients({ bufnr = bufnr, name = client_name }) > 0
  end, 50)
end

local function wait_for_diagnostics(bufnr, timeout)
  return vim.wait(timeout, function() return published[bufnr] == true end, 50)
end

local function inspect_path(path)
  vim.cmd.edit(vim.fn.fnameescape(path))

  local bufnr = vim.api.nvim_get_current_buf()
  published[bufnr] = false

  local attached = wait_for_client(bufnr, 5000)
  local received = attached and wait_for_diagnostics(bufnr, 1000) or false
  local diagnostics = unique_diagnostics(vim.diagnostic.get(bufnr))

  return {
    path = path,
    attached = attached,
    received = received,
    diagnostics = diagnostics,
  }
end

local function format_diagnostic(diagnostic)
  local namespace = diagnostic.namespace and vim.diagnostic.get_namespace(diagnostic.namespace) or nil
  local code = diagnostic.code and (' [' .. diagnostic.code .. ']') or ''
  local source = namespace and namespace.name and (' [' .. namespace.name .. ']') or ''
  local message = diagnostic.message:gsub('\n', ' ')

  return string.format(
    '  %d:%d [%s]%s%s %s',
    diagnostic.lnum + 1,
    diagnostic.col + 1,
    severity_names[diagnostic.severity] or tostring(diagnostic.severity),
    source,
    code,
    message
  )
end

local function print_report(reports)
  local files_with_diagnostics = 0
  local total_diagnostics = 0
  local unattached_files = 0

  for _, report in ipairs(reports) do
    if #report.diagnostics > 0 then
      files_with_diagnostics = files_with_diagnostics + 1
      total_diagnostics = total_diagnostics + #report.diagnostics

      print(relative_path(report.path))
      for _, diagnostic in ipairs(report.diagnostics) do
        print(format_diagnostic(diagnostic))
      end
    elseif not report.attached then
      unattached_files = unattached_files + 1
      print(relative_path(report.path))
      print('  [ERROR] No lua_ls client attached')
    end
  end

  if total_diagnostics == 0 and unattached_files == 0 then
    print('No live Lua diagnostics found')
  else
    print(string.format('Total live Lua diagnostics: %d in %d file(s)', total_diagnostics, files_with_diagnostics))
  end

  return total_diagnostics, unattached_files
end

local reports = {}
for _, path in ipairs(default_paths()) do
  table.insert(reports, inspect_path(path))
end

local total_diagnostics, unattached_files = print_report(reports)
if total_diagnostics > 0 or unattached_files > 0 then vim.cmd.cquit(1) end
