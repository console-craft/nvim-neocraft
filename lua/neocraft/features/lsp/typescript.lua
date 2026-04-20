-- Provide vtsls-specific navigation and code action helpers.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

-- Open one location directly or show a picker when multiple matches are returned.
---@param result lsp.Location|lsp.LocationLink|(lsp.Location|lsp.LocationLink)[]|nil
---@param client vim.lsp.Client
---@param title string
local function open_locations(result, client, title)
  local pickers = require('neocraft.features.pickers')
  local locations = result == nil and {} or (vim.islist(result) and result or { result })
  if vim.tbl_isempty(locations) then
    vim.notify('No ' .. title:lower() .. ' found', vim.log.levels.INFO)
    return
  end

  if #locations == 1 then
    vim.lsp.util.show_document(locations[1], client.offset_encoding, {
      focus = true,
      reuse_win = true,
    })
    return
  end

  pickers.lsp_locations(locations, {
    title = title,
    position_encoding = client.offset_encoding,
  })
end

-- Return the first attached vtsls client for the target buffer.
---@param bufnr? integer
---@return vim.lsp.Client?
local function typescript_client(bufnr) return vim.lsp.get_clients({ bufnr = bufnr or 0, name = 'vtsls' })[1] end

-- Run a callback only when vtsls is attached to the target buffer.
---@generic T
---@param bufnr? integer
---@param callback fun(client: vim.lsp.Client, bufnr: integer): T?
---@return T?
local function with_typescript_client(bufnr, callback)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local client = typescript_client(bufnr)
  if not client then
    vim.notify('vtsls is not attached to the current buffer', vim.log.levels.INFO)
    return nil
  end

  return callback(client, bufnr)
end

-- Execute a vtsls workspace command and optionally handle its result.
local function typescript_execute_command(command, opts)
  opts = opts or {}

  return with_typescript_client(opts.bufnr, function(client, bufnr)
    local arguments = opts.arguments
    if type(arguments) == 'function' then arguments = arguments(client, bufnr) end

    client:request('workspace/executeCommand', {
      command = command,
      arguments = arguments or {},
    }, function(err, result)
      if err then
        vim.notify(
          ('TypeScript command `%s` failed: %s'):format(command, err.message or err.code),
          vim.log.levels.ERROR
        )
        return
      end

      if type(opts.on_result) == 'function' then opts.on_result(result, client, bufnr) end
    end, bufnr)
  end)
end

-- Apply a TypeScript-specific code action through the attached vtsls client.
---@param kind string
---@param bufnr? integer
local function typescript_code_action(kind, bufnr)
  with_typescript_client(bufnr, function(client)
    vim.lsp.buf.code_action({
      apply = true,
      context = {
        diagnostics = {},
        only = { kind },
      },
      filter = function(_, client_id) return client_id == client.id end,
    })
  end)
end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Jump to the source definition reported by vtsls.
function M.typescript_source_definition(bufnr)
  return typescript_execute_command('typescript.goToSourceDefinition', {
    bufnr = bufnr,
    arguments = function(client)
      local params = vim.lsp.util.make_position_params(vim.api.nvim_get_current_win(), client.offset_encoding)
      return { params.textDocument.uri, params.position }
    end,
    on_result = function(result, client) open_locations(result, client, 'TypeScript source definitions') end,
  })
end

-- Show references to the current TypeScript file.
function M.typescript_file_references(bufnr)
  return typescript_execute_command('typescript.findAllFileReferences', {
    bufnr = bufnr,
    arguments = function(_, resolved_bufnr) return { vim.uri_from_bufnr(resolved_bufnr) } end,
    on_result = function(result, client) open_locations(result, client, 'TypeScript file references') end,
  })
end

-- Organize imports using the TypeScript server.
function M.typescript_organize_imports(bufnr) return typescript_code_action('source.organizeImports', bufnr) end

-- Add missing imports using the TypeScript server.
function M.typescript_add_missing_imports(bufnr) return typescript_code_action('source.addMissingImports.ts', bufnr) end

-- Remove unused imports using the TypeScript server.
function M.typescript_remove_unused_imports(bufnr) return typescript_code_action('source.removeUnused.ts', bufnr) end

-- Open the TypeScript version picker for the current workspace.
function M.typescript_select_version(bufnr)
  return typescript_execute_command('typescript.selectTypeScriptVersion', {
    bufnr = bufnr,
  })
end

-- Open the active TypeScript server log.
function M.typescript_open_log(bufnr)
  return typescript_execute_command('typescript.openTsServerLog', {
    bufnr = bufnr,
  })
end

-- Restart the active TypeScript server.
function M.typescript_restart(bufnr)
  return typescript_execute_command('typescript.restartTsServer', {
    bufnr = bufnr,
  })
end

return M
