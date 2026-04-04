local pack = require('neocraft.core.pack')

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ LSP servers and tools to auto-install     │
-- └───────────────────────────────────────────┘

M.servers = {
  lua_ls = {},
  jsonls = {},
  yamlls = {},
  gh_actions_ls = {},
  dockerls = {},
  docker_compose_language_service = {},
  taplo = {},
  bashls = {},
  marksman = {},
}

M.tools = {
  'luacheck',
  'stylua',
  'shfmt',
}

-- ┌───────────────────────────────────────────┐
-- │ Install LSP related plugins               │
-- └───────────────────────────────────────────┘

pack.add('lsp', {
  { src = 'https://github.com/mason-org/mason.nvim' },
  { src = 'https://github.com/mason-org/mason-lspconfig.nvim' },
  { src = 'https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim' },
  { src = 'https://github.com/neovim/nvim-lspconfig' },
  { src = 'https://github.com/b0o/SchemaStore.nvim' },
})

-- ┌───────────────────────────────────────────┐
-- │ Core LSP setup                            │
-- └───────────────────────────────────────────┘

local function file_operation_capabilities()
  return {
    workspace = {
      fileOperations = {
        didRename = true,
        willRename = true,
      },
    },
  }
end

local function server_names() return vim.tbl_keys(M.servers) end

local function ensure_installed() return vim.list_extend(server_names(), vim.deepcopy(M.tools)) end

Lib.now(function()
  require('mason').setup({
    ui = {
      icons = {
        package_installed = '✓',
        package_pending = '➜',
        package_uninstalled = '✗',
      },
      border = vim.o.winborder,
    },
  })

  require('mason-tool-installer').setup({
    ensure_installed = ensure_installed(),
  })

  vim.lsp.config('*', {
    capabilities = file_operation_capabilities(),
  })

  for _, name in ipairs(server_names()) do
    vim.lsp.config(name, M.servers[name])
    vim.lsp.enable(name)
  end
end)

-- ┌───────────────────────────────────────────┐
-- │ Handle file move/rename                   │
-- └───────────────────────────────────────────┘

local function normalize_path(path)
  if type(path) ~= 'string' or path == '' then return nil end
  return vim.fs.normalize(path)
end

local function path_is_within(path, root_dir)
  path = normalize_path(path)
  root_dir = normalize_path(root_dir)
  if not path or not root_dir then return false end
  if path == root_dir then return true end
  return vim.startswith(path, root_dir .. '/')
end

local function client_roots(client)
  local roots = {}
  local seen = {}

  local function add(path)
    path = normalize_path(path)
    if not path or seen[path] then return end
    seen[path] = true
    table.insert(roots, path)
  end

  for _, folder in ipairs(client.workspace_folders or {}) do
    if type(folder.uri) == 'string' and folder.uri ~= '' then add(vim.uri_to_fname(folder.uri)) end
  end

  if type(client.root_dir) == 'string' then add(client.root_dir) end
  if type(client.config.root_dir) == 'string' then add(client.config.root_dir) end

  for buf in pairs(client.attached_buffers or {}) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= '' then add(name) end
  end

  return roots
end

local function client_handles_path(client, path)
  for _, root_dir in ipairs(client_roots(client)) do
    if path_is_within(path, root_dir) then return true end
  end

  return false
end

local function rename_params(from, to)
  return {
    files = {
      {
        oldUri = vim.uri_from_fname(from),
        newUri = vim.uri_from_fname(to),
      },
    },
  }
end

local function notify_lsp_file_rename(from, to)
  from = normalize_path(from)
  to = normalize_path(to)
  if not from or not to or from == to then return end

  local params = rename_params(from, to)

  for _, client in ipairs(vim.lsp.get_clients()) do
    if client_handles_path(client, from) or client_handles_path(client, to) then
      if client:supports_method('workspace/willRenameFiles') then
        local response = client:request_sync('workspace/willRenameFiles', params, 1000)
        if response and response.result then
          vim.lsp.util.apply_workspace_edit(response.result, client.offset_encoding)
        end
      end

      if client:supports_method('workspace/didRenameFiles') then client:notify('workspace/didRenameFiles', params) end
    end
  end
end

local group = Lib.augroup('lsp')

Lib.autocmd('User', {
  group = group,
  pattern = { 'MiniFilesActionRename', 'MiniFilesActionMove' },
  desc = 'Notify LSP clients after mini.files rename and move actions',
  callback = function(args)
    local data = args.data or {}
    notify_lsp_file_rename(data.from, data.to)
  end,
})

-- ┌───────────────────────────────────────────┐
-- │ LSP mappings and hints/lens enabling      │
-- └───────────────────────────────────────────┘

local function refresh_clue_triggers(bufnr)
  local ok, clue = pcall(require, 'mini.clue')
  if not ok then return end

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then clue.ensure_buf_triggers(bufnr) end
  end)
end

local function format_buffer(bufnr) return vim.lsp.buf.format({ bufnr = bufnr }) end

local function show_attached_clients(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if vim.tbl_isempty(clients) then
    vim.notify('No LSP clients attached to the current buffer', vim.log.levels.WARN)
    return
  end

  local names = vim.tbl_map(function(client) return client.name end, clients)
  table.sort(names)

  vim.notify(table.concat(names, '\n'), vim.log.levels.INFO, {
    title = 'Attached LSP Clients',
  })
end

local function lsp_picker(scope)
  return function() require('mini.extra').pickers.lsp({ scope = scope }) end
end

local Methods = vim.lsp.protocol.Methods

local function add_mini_clue_code_group(bufnr)
  local config = vim.b[bufnr].miniclue_config or {}
  local clues = vim.deepcopy(config.clues or {})

  for _, clue in ipairs(clues) do
    if clue.mode == 'n' and clue.keys == '<Leader>c' and clue.desc == '+Code' then return end
  end

  table.insert(clues, { mode = 'n', keys = '<Leader>c', desc = '+Code' })
  config.clues = clues
  vim.b[bufnr].miniclue_config = config
end

if vim.fn.exists(':LspInfo') ~= 2 then
  vim.api.nvim_create_user_command('LspInfo', 'checkhealth vim.lsp', {
    desc = 'Alias to `:checkhealth vim.lsp`',
  })
end

if vim.fn.exists(':LspAttached') ~= 2 then
  vim.api.nvim_create_user_command('LspAttached', function(opts)
    local bufnr = opts.args ~= '' and tonumber(opts.args) or vim.api.nvim_get_current_buf()
    show_attached_clients(bufnr)
  end, {
    desc = 'Show LSP clients attached to the current buffer',
    nargs = '?',
  })
end

Lib.autocmd('LspAttach', {
  group = group,
  desc = 'Configure buffer-local LSP mappings and clues',
  callback = function(args)
    local bufnr = args.buf
    local client_id = args.data and args.data.client_id
    local client = client_id and vim.lsp.get_client_by_id(client_id) or nil
    if not client then return end

    add_mini_clue_code_group(bufnr)

    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
    end

    if client:supports_method(Methods.textDocument_references, bufnr) then
      map('n', 'grr', lsp_picker('references'), 'Goto references')
    end

    if client:supports_method(Methods.textDocument_implementation, bufnr) then
      map('n', 'gri', lsp_picker('implementation'), 'Goto implementation')
    end

    if client:supports_method(Methods.textDocument_typeDefinition, bufnr) then
      map('n', 'grt', lsp_picker('type_definition'), 'Goto type definition')
    end

    if client:supports_method(Methods.textDocument_documentSymbol, bufnr) then
      map('n', 'gO', lsp_picker('document_symbol'), 'Document symbols')
    end

    if client:supports_method(Methods.workspace_symbol, bufnr) then
      map('n', 'gW', lsp_picker('workspace_symbol_live'), 'Workspace symbols')
    end

    if client:supports_method(Methods.textDocument_signatureHelp, bufnr) then
      map('i', '<C-k>', vim.lsp.buf.signature_help, 'Signature help')
    end

    if client:supports_method(Methods.textDocument_formatting, bufnr) then
      map('n', '<Leader>cf', function() format_buffer(bufnr) end, 'Format buffer')
    end

    map('n', '<Leader>cd', vim.diagnostic.open_float, 'Line diagnostics')

    map('n', '<Leader>ca', function() show_attached_clients(bufnr) end, 'Attached LSP clients')

    map('n', '<Leader>ci', '<Cmd>LspInfo<CR>', 'LSP info')

    if client:supports_method(Methods.textDocument_inlayHint, bufnr) then
      vim.defer_fn(function() vim.lsp.inlay_hint.enable(true, { bufnr = bufnr }) end, 0)
    end

    if client:supports_method(Methods.textDocument_codeLens, bufnr) then
      vim.lsp.codelens.enable(true, { bufnr = bufnr })
    end

    refresh_clue_triggers(bufnr)
  end,
})

-- ┌───────────────────────────────────────────┐
-- │ Toggle helpers                            │
-- └───────────────────────────────────────────┘

local function any_client_supports_method(bufnr, method)
  return #vim.lsp.get_clients({ bufnr = bufnr, method = method }) > 0
end

function M.toggle_inlay_hints()
  local bufnr = vim.api.nvim_get_current_buf()
  if not any_client_supports_method(bufnr, Methods.textDocument_inlayHint) then
    vim.notify('No attached LSP client supports inlay hints for this buffer', vim.log.levels.INFO)
    return
  end

  local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
  vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
  vim.api.nvim_echo({ { (enabled and 'Disabled: ' or 'Enabled: ') .. 'inlay hints', 'Normal' } }, false, {})
end

function M.toggle_codelens()
  local bufnr = vim.api.nvim_get_current_buf()
  if not any_client_supports_method(bufnr, Methods.textDocument_codeLens) then
    vim.notify('No attached LSP client supports code lens for this buffer', vim.log.levels.INFO)
    return
  end

  local enabled = vim.lsp.codelens.is_enabled({ bufnr = bufnr })
  vim.lsp.codelens.enable(not enabled, { bufnr = bufnr })
  vim.api.nvim_echo({ { (enabled and 'Disabled: ' or 'Enabled: ') .. 'code lens', 'Normal' } }, false, {})
end

return M
