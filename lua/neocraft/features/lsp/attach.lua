-- Configure buffer-local LSP behavior when clients attach.

local M = {}

local group = Lib.augroup('lsp-attach')
local Methods = vim.lsp.protocol.Methods

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

-- Check whether the attached client is Copilot.
---@param client vim.lsp.Client
---@return boolean
local function is_copilot_client(client) return client.name == 'copilot' end

-- Refresh mini.clue triggers after buffer-local LSP mappings are added.
---@param bufnr integer
local function refresh_clue_triggers(bufnr)
  local ok, clue = pcall(require, 'mini.clue')
  if not ok then return end

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then clue.ensure_buf_triggers(bufnr) end
  end)
end

-- Show the current buffer's attached LSP clients in a scratch tab.
---@param bufnr? integer
local function show_attached_clients(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  table.sort(clients, function(a, b)
    if a.name == b.name then return a.id < b.id end
    return a.name < b.name
  end)

  local path = vim.api.nvim_buf_get_name(bufnr)
  local lines = {
    'Attached LSP Clients',
    '',
    'Buffer: ' .. bufnr,
    'Path: ' .. (path ~= '' and path or '<unnamed>'),
    '',
  }

  if vim.tbl_isempty(clients) then
    table.insert(lines, 'No LSP clients attached to this buffer.')
  else
    for _, client in ipairs(clients) do
      table.insert(lines, '- ' .. client.name)
    end
  end

  vim.cmd.tabnew()

  local placeholder = vim.api.nvim_get_current_buf()

  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, scratch)
  vim.bo[scratch].buftype = 'nofile'
  vim.bo[scratch].bufhidden = 'wipe'
  vim.bo[scratch].buflisted = false
  vim.bo[scratch].filetype = 'neocraft-lsp-clients'
  vim.bo[scratch].modifiable = true
  vim.bo[scratch].swapfile = false
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, lines)
  vim.bo[scratch].modifiable = false
  vim.bo[scratch].modified = false

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(scratch) then return end

    local ok, clue = pcall(require, 'mini.clue')
    if not ok then return end

    clue.ensure_buf_triggers(scratch)
  end)

  if placeholder ~= scratch and vim.api.nvim_buf_is_valid(placeholder) then
    pcall(vim.api.nvim_buf_delete, placeholder, { force = true })
  end
end

-- Build a mini.extra LSP picker callback for the given scope.
local function lsp_picker(scope)
  return function() require('mini.extra').pickers.lsp({ scope = scope }) end
end

---@param result lsp.Location|lsp.LocationLink|(lsp.Location|lsp.LocationLink)[]|nil
---@return (lsp.Location|lsp.LocationLink)[]
local function normalize_locations(result) return result == nil and {} or (vim.islist(result) and result or { result }) end

-- Jump directly for a single LSP location, otherwise keep the picker flow for choosing among many.
---@param scope string
---@param method string
---@param empty_message string
---@return function
local function lsp_location_or_picker(scope, method, empty_message)
  return function()
    local bufnr = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()
    local clients = vim.lsp.get_clients({ bufnr = bufnr, method = method })
    if vim.tbl_isempty(clients) then
      vim.notify('No LSP provider attached', vim.log.levels.INFO)
      return
    end

    local pending = #clients
    local locations = {}
    local errors = {}

    local function finish()
      pending = pending - 1
      if pending > 0 then return end

      if vim.tbl_isempty(locations) then
        if #errors > 0 then
          vim.notify(errors[1], vim.log.levels.ERROR)
        else
          vim.notify(empty_message, vim.log.levels.INFO)
        end
        return
      end

      if #locations == 1 then
        local item = locations[1]
        local open = function()
          vim.lsp.util.show_document(item.location, item.client.offset_encoding, {
            focus = true,
            reuse_win = true,
          })
          vim.cmd('normal! zz')
        end

        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_call(win, open)
        else
          open()
        end
        return
      end

      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_call(win, lsp_picker(scope))
      else
        lsp_picker(scope)()
      end
    end

    for _, client in ipairs(clients) do
      local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
      client:request(method, params, function(err, result)
        if err then
          table.insert(errors, err.message or 'LSP location request failed')
        else
          for _, location in ipairs(normalize_locations(result)) do
            table.insert(locations, { location = location, client = client })
          end
        end

        finish()
      end, bufnr)
    end
  end
end

-- Check whether inlay hints are globally enabled.
local function inlay_hints_enabled() return vim.g.enable_inlay_hints == true end

-- Check whether code lens is globally enabled.
local function codelens_enabled() return vim.g.enable_codelens == true end

-- Check whether inline completions are globally enabled.
local function inline_completions_enabled() return vim.g.enable_inline_completions == true end

-- Create shared user commands for LSP health and attached-client inspection.
local function create_common_commands()
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
end

-- Return the first attached client that can resolve definitions.
---@param bufnr integer
---@return vim.lsp.Client?
local function definition_client(bufnr)
  return vim.lsp.get_clients({ bufnr = bufnr, method = Methods.textDocument_definition })[1]
end

-- Open one definition directly in a vertical split or show a picker when multiple matches are returned.
---@param result lsp.Location|lsp.LocationLink|(lsp.Location|lsp.LocationLink)[]|nil
---@param client vim.lsp.Client
local function open_definition_locations(result, client)
  local locations = result == nil and {} or (vim.islist(result) and result or { result })
  if vim.tbl_isempty(locations) then
    vim.notify('No LSP definitions found', vim.log.levels.INFO)
    return
  end

  vim.cmd.vsplit()

  if #locations == 1 then
    vim.lsp.util.show_document(locations[1], client.offset_encoding, {
      focus = true,
      reuse_win = false,
    })
    vim.cmd('normal! zz')
    return
  end

  require('neocraft.features.pickers').lsp_locations(locations, {
    title = 'LSP Definitions',
    position_encoding = client.offset_encoding,
  })
end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Open the attached-client scratch view for the target buffer.
---@param bufnr? integer
function M.show_attached_clients(bufnr) return show_attached_clients(bufnr) end

-- Open the built-in LSP info panel for the current buffer.
function M.lsp_info() vim.cmd.LspInfo() end

-- Open a vertical split, jump to the LSP definition, and center the destination.
function M.definition_in_vsplit()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = definition_client(bufnr)
  if client == nil then
    vim.notify('No LSP definition provider attached', vim.log.levels.INFO)
    return
  end

  local params = vim.lsp.util.make_position_params(vim.api.nvim_get_current_win(), client.offset_encoding)
  client:request(Methods.textDocument_definition, params, function(err, result)
    if err then
      vim.notify(err.message or 'LSP definition request failed', vim.log.levels.ERROR)
      return
    end

    open_definition_locations(result, client)
  end, bufnr)
end

-- Register buffer-local LSP mappings, commands, and feature setup on attach.
function M.setup(modules)
  create_common_commands()

  Lib.autocmd('LspAttach', {
    group = group,
    desc = 'Configure buffer-local LSP mappings and clues',
    callback = function(args)
      local bufnr = args.buf
      local client_id = args.data and args.data.client_id
      local client = client_id and vim.lsp.get_client_by_id(client_id) or nil
      if not client then return end

      vim.bo[bufnr].omnifunc = 'v:lua.MiniCompletion.completefunc_lsp'

      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
      end

      if client:supports_method(Methods.textDocument_hover, bufnr) then
        map('n', 'K', vim.lsp.buf.hover, 'Hover documentation')
      end

      if client:supports_method(Methods.textDocument_references, bufnr) then
        map('n', 'grr', lsp_picker('references'), 'Go to references')
      end

      if client:supports_method(Methods.textDocument_implementation, bufnr) then
        map(
          'n',
          'gri',
          lsp_location_or_picker('implementation', Methods.textDocument_implementation, 'No LSP implementations found'),
          'Go to implementation'
        )
      end

      if client:supports_method(Methods.textDocument_typeDefinition, bufnr) then
        map(
          'n',
          'grt',
          lsp_location_or_picker(
            'type_definition',
            Methods.textDocument_typeDefinition,
            'No LSP type definitions found'
          ),
          'Go to type definition'
        )
      end

      if client:supports_method(Methods.textDocument_declaration, bufnr) then
        map('n', 'gD', vim.lsp.buf.declaration, 'Go to declaration')
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

      if inlay_hints_enabled() and client:supports_method(Methods.textDocument_inlayHint, bufnr) then
        if vim.b[bufnr].neocraft_inlay_hints_enabled == nil then vim.b[bufnr].neocraft_inlay_hints_enabled = true end
      end

      if codelens_enabled() and client:supports_method(Methods.textDocument_codeLens, bufnr) then
        if vim.b[bufnr].neocraft_codelens_enabled == nil then vim.b[bufnr].neocraft_codelens_enabled = true end
      end

      if
        client:supports_method(Methods.textDocument_inlayHint, bufnr)
        or client:supports_method(Methods.textDocument_codeLens, bufnr)
      then
        vim.defer_fn(function()
          if vim.api.nvim_buf_is_valid(bufnr) then modules.annotations.reset_buffer_annotations(bufnr) end
        end, 0)
      end

      if
        inline_completions_enabled()
        and is_copilot_client(client)
        and client:supports_method(Methods.textDocument_inlineCompletion, bufnr)
      then
        vim.lsp.inline_completion.enable(true, { client_id = client.id })

        map(
          'i',
          '<M-]>',
          modules.copilot.trigger_or_cycle_inline_completion(bufnr),
          'Next / Retrigger inline completion'
        )
        map('i', '<M-[>', function() vim.lsp.inline_completion.select({ count = -1 }) end, 'Previous inline completion')
      end

      if is_copilot_client(client) then
        map('n', '<Leader>cci', function() modules.copilot.copilot_sign_in(bufnr) end, 'Sign in')
        map('n', '<Leader>cco', function() modules.copilot.copilot_sign_out(bufnr) end, 'Sign out')
      end

      if client.name == 'vtsls' then
        map(
          'n',
          'gD',
          function() modules.typescript.typescript_source_definition(bufnr) end,
          'TS: Go to source definition'
        )
        map('n', 'gR', function() modules.typescript.typescript_file_references(bufnr) end, 'TS: Go to file references')
        map('n', '<Leader>clt', function() modules.typescript.typescript_open_log(bufnr) end, 'TS: Open server log')
        map(
          'n',
          '<Leader>cO',
          function() modules.typescript.typescript_organize_imports(bufnr) end,
          'TS: Organize imports'
        )
        map(
          'n',
          '<Leader>cM',
          function() modules.typescript.typescript_add_missing_imports(bufnr) end,
          'TS: Add missing imports'
        )
        map(
          'n',
          '<Leader>cU',
          function() modules.typescript.typescript_remove_unused_imports(bufnr) end,
          'TS: Remove unused imports'
        )
        map('n', '<Leader>cR', function() modules.typescript.typescript_restart(bufnr) end, 'TS: Restart server')
        map(
          'n',
          '<Leader>cV',
          function() modules.typescript.typescript_select_version(bufnr) end,
          'TS: Select workspace version'
        )

        local create_buffer_command = function(name, rhs, desc)
          if vim.api.nvim_buf_get_commands(bufnr, {})[name] ~= nil then return end
          vim.api.nvim_buf_create_user_command(bufnr, name, rhs, { desc = desc })
        end

        create_buffer_command(
          'TypeScriptVersion',
          function() modules.typescript.typescript_select_version(bufnr) end,
          'TS: Select workspace version'
        )
        create_buffer_command(
          'TypeScriptOpenLog',
          function() modules.typescript.typescript_open_log(bufnr) end,
          'TS: Open server log'
        )
        create_buffer_command(
          'TypeScriptRestart',
          function() modules.typescript.typescript_restart(bufnr) end,
          'TS: Restart server'
        )
      end

      if client.name == 'ruff' then
        map('n', '<Leader>cO', function() modules.python.python_organize_imports(bufnr) end, 'Py: Organize imports')
      end

      if client.name == 'basedpyright' then
        map('n', '<Leader>cV', modules.python.python_select_venv, 'Py: Select virtual environment')
      end

      refresh_clue_triggers(bufnr)
    end,
  })
end

return M
