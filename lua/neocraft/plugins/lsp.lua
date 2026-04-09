local pack = require('neocraft.core.pack')

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local group = Lib.augroup('lsp')

local Methods = vim.lsp.protocol.Methods

local function is_copilot_client(client) return client.name == 'copilot' end

local function nes_enabled() return vim.g.enable_NES == true end

-- ┌───────────────────────────────────────────┐
-- │ LSP servers and tools to auto-install     │
-- └───────────────────────────────────────────┘

M.servers = {
  copilot = {},
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
  { src = 'https://github.com/copilotlsp-nvim/copilot-lsp' },
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

local function lsp_capabilities()
  return vim.tbl_deep_extend('force', file_operation_capabilities(), require('mini.completion').get_lsp_capabilities())
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

  if nes_enabled() then
    require('copilot-lsp').setup({
      nes = {
        move_count_threshold = 100,
        distance_threshold = 40,
        clear_on_large_distance = false,
        count_horizontal_moves = true,
        reset_on_approaching = true,
      },
    })
  end

  vim.lsp.config('*', {
    capabilities = lsp_capabilities(),
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
-- │ Buffer annotations                        │
-- └───────────────────────────────────────────┘

local function mini_diff_overlay_active(bufnr)
  local ok, mini_diff = pcall(require, 'mini.diff')
  if not ok then return false end

  local ok_data, data = pcall(mini_diff.get_buf_data, bufnr)
  return ok_data and data ~= nil and data.overlay == true
end

local function annotations_temporarily_disabled(bufnr)
  return mini_diff_overlay_active(bufnr) or vim.api.nvim_get_mode().mode:match('^i') ~= nil
end

local function any_client_supports_method(bufnr, method)
  return #vim.lsp.get_clients({ bufnr = bufnr, method = method }) > 0
end

local function reset_inlay_hints(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not any_client_supports_method(bufnr, Methods.textDocument_inlayHint) then return end

  local should_enable = vim.b[bufnr].neocraft_inlay_hints_enabled == true
    and not annotations_temporarily_disabled(bufnr)
  vim.lsp.inlay_hint.enable(should_enable, { bufnr = bufnr })
end

local function reset_codelens(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not any_client_supports_method(bufnr, Methods.textDocument_codeLens) then return end

  local should_enable = vim.b[bufnr].neocraft_codelens_enabled == true and not annotations_temporarily_disabled(bufnr)
  vim.lsp.codelens.enable(should_enable, { bufnr = bufnr })
end

function M.reset_buffer_annotations(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  reset_inlay_hints(bufnr)
  reset_codelens(bufnr)
end

function M.toggle_inlay_hints()
  local bufnr = vim.api.nvim_get_current_buf()
  if not any_client_supports_method(bufnr, Methods.textDocument_inlayHint) then
    vim.notify('No attached LSP client supports inlay hints for this buffer', vim.log.levels.INFO)
    return
  end

  local enabled = vim.b[bufnr].neocraft_inlay_hints_enabled == true
  vim.b[bufnr].neocraft_inlay_hints_enabled = not enabled
  reset_inlay_hints(bufnr)
  vim.api.nvim_echo({ { (enabled and 'Disabled: ' or 'Enabled: ') .. 'inlay hints', 'Normal' } }, false, {})
end

function M.toggle_codelens()
  local bufnr = vim.api.nvim_get_current_buf()
  if not any_client_supports_method(bufnr, Methods.textDocument_codeLens) then
    vim.notify('No attached LSP client supports code lens for this buffer', vim.log.levels.INFO)
    return
  end

  local enabled = vim.b[bufnr].neocraft_codelens_enabled == true
  vim.b[bufnr].neocraft_codelens_enabled = not enabled
  reset_codelens(bufnr)
  vim.api.nvim_echo({ { (enabled and 'Disabled: ' or 'Enabled: ') .. 'code lens', 'Normal' } }, false, {})
end

local function hide_buffer_annotations(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if any_client_supports_method(bufnr, Methods.textDocument_inlayHint) then
    vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
  end
  if any_client_supports_method(bufnr, Methods.textDocument_codeLens) then
    vim.lsp.codelens.enable(false, { bufnr = bufnr })
  end
end

Lib.autocmd('InsertEnter', {
  group = group,
  desc = 'Hide annotations while typing',
  callback = function(args) hide_buffer_annotations(args.buf) end,
})

Lib.autocmd('InsertLeave', {
  group = group,
  desc = 'Restore annotations after Insert mode',
  callback = function(args) M.reset_buffer_annotations(args.buf) end,
})

-- ┌───────────────────────────────────────────┐
-- │ Copilot LSP & inline completion helpers   │
-- └───────────────────────────────────────────┘

local function copilot_client(bufnr) return vim.lsp.get_clients({ bufnr = bufnr or 0, name = 'copilot' })[1] end

local function run_copilot_command(command, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not copilot_client(bufnr) then
    vim.notify('Copilot is not attached to the current buffer', vim.log.levels.INFO)
    return
  end

  local commands = vim.api.nvim_buf_get_commands(bufnr, {})
  if commands[command] == nil then
    vim.notify('Copilot command `' .. command .. '` is not available in this buffer', vim.log.levels.WARN)
    return
  end

  vim.api.nvim_buf_call(bufnr, function() vim.cmd(command) end)
end

function M.copilot_sign_in(bufnr) run_copilot_command('LspCopilotSignIn', bufnr) end

function M.copilot_sign_out(bufnr) run_copilot_command('LspCopilotSignOut', bufnr) end

local function first_different_char_index(a, b)
  local index, length_a, length_b = 1, #a, #b
  while index <= length_a and index <= length_b and a:sub(index, index) == b:sub(index, index) do
    index = index + 1
  end
  return index
end

local function parse_visible_inline_text(item)
  if type(item.insert_text) ~= 'string' then return nil end

  local suggested_lines = vim.split(item.insert_text, '\n', { plain = true })
  local suggested_insertion_pos = item.range and item.range.start:to_extmark()
    or vim.pos.cursor(vim.api.nvim_win_get_cursor(0)):to_extmark()
  local suggested_insertion_row, suggested_insertion_col = unpack(suggested_insertion_pos)
  local existing_line_text =
    vim.api.nvim_buf_get_lines(0, suggested_insertion_row, suggested_insertion_row + 1, false)[1]

  if not (existing_line_text and #existing_line_text >= suggested_insertion_col) then return nil end

  local existing_line_text_to_right_of_insertion = existing_line_text:sub(suggested_insertion_col + 1)
  local insertion_index = first_different_char_index(existing_line_text_to_right_of_insertion, suggested_lines[1])

  local current_cursor_row, current_cursor_col = unpack(vim.pos.cursor(vim.api.nvim_win_get_cursor(0)):to_extmark())
  local may_have_advanced_index = current_cursor_col - suggested_insertion_col + 1
  if suggested_insertion_row == current_cursor_row then
    insertion_index = math.max(insertion_index, may_have_advanced_index)
  end

  return {
    append_to_current_line_text = suggested_lines[1]:sub(insertion_index),
    next_suggested_line_text = suggested_lines[2],
    existing_line_text = suggested_lines[1]:sub(1, insertion_index - 1),
  }
end

local function build_eol_item(item)
  local parsed = parse_visible_inline_text(item)
  if parsed == nil then return nil end

  local patched = vim.deepcopy(item)
  local insert_text = parsed.existing_line_text .. parsed.append_to_current_line_text

  if parsed.next_suggested_line_text ~= nil then
    insert_text = insert_text .. '\n' .. (parsed.next_suggested_line_text:match('^%s*') or '')
  end

  patched.insert_text = insert_text
  return patched
end

function M.accept_inline_completion_to_eol(bufnr)
  return vim.lsp.inline_completion.get({
    bufnr = bufnr,
    on_accept = build_eol_item,
  })
end

local function inline_completion_visible(bufnr)
  local ns = vim.api.nvim_get_namespaces()['nvim.lsp.inline_completion']
  if ns == nil then return false end

  return #vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { limit = 1 }) > 0
end

local function inline_completor(bufnr)
  local _, completor = debug.getupvalue(vim.lsp.inline_completion.get, 1)
  if type(completor) ~= 'table' or type(completor.active) ~= 'table' then return nil end
  return completor.active[bufnr]
end

local function retrigger_inline_completion(bufnr)
  local completor = inline_completor(bufnr)
  if completor == nil or type(completor.request) ~= 'function' then return false end

  completor:abort()
  completor:request(vim.lsp.protocol.InlineCompletionTriggerKind.Invoked)
  return true
end

function M.trigger_or_cycle_inline_completion(bufnr)
  return function()
    if inline_completion_visible(bufnr) then
      vim.lsp.inline_completion.select({ bufnr = bufnr })
      return
    end

    retrigger_inline_completion(bufnr)
  end
end

-- ┌───────────────────────────────────────────┐
-- │ Copilot Next Edit Suggestions (NES)       │
-- └───────────────────────────────────────────┘

local COPILOT_NES_DEBOUNCE_MS = 100
local COPILOT_NES_RESHOW_AFTER_DISMISS_COUNT = 3

local function attached_copilot_client(client_id, bufnr)
  local client = vim.lsp.get_client_by_id(client_id)
  if not client or not is_copilot_client(client) or not client.attached_buffers[bufnr] then return nil end
  return client
end

local function notify_copilot_did_focus(bufnr, client_id)
  local client = attached_copilot_client(client_id, bufnr)
  if client == nil then return end

  ---@diagnostic disable-next-line:param-type-mismatch -- Copilot NES uses a custom notification.
  client:notify('textDocument/didFocus', {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
  })
end

local function dismissed_nes(bufnr)
  local edit = vim.b[bufnr].neocraft_dismissed_nes
  return type(edit) == 'table' and edit or nil
end

local function revive_dismissed_nes(bufnr)
  local edit = dismissed_nes(bufnr)
  if edit == nil or not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_get_current_buf() ~= bufnr then
    return false
  end
  if not vim.api.nvim_get_mode().mode:match('^n') then return false end

  local ns_id = vim.b[bufnr].copilotlsp_nes_namespace_id or vim.api.nvim_create_namespace('copilotlsp.nes')
  return require('copilot-lsp.nes.ui')._display_next_suggestion(bufnr, ns_id, { vim.deepcopy(edit) })
end

local function clear_nes_reshow_budget(bufnr) vim.b[bufnr].neocraft_nes_reshow_budget = nil end

local function consume_nes_reshow_budget(bufnr)
  local remaining = vim.b[bufnr].neocraft_nes_reshow_budget or 0
  if remaining <= 0 then
    clear_nes_reshow_budget(bufnr)
    return false
  end

  remaining = remaining - 1
  if remaining > 0 then
    vim.b[bufnr].neocraft_nes_reshow_budget = remaining
  else
    clear_nes_reshow_budget(bufnr)
  end

  return true
end

local function clear_dismissed_nes(bufnr) vim.b[bufnr].neocraft_dismissed_nes = nil end

local function clear_nes_reshow_state(bufnr)
  clear_nes_reshow_budget(bufnr)
  clear_dismissed_nes(bufnr)
end

local function request_copilot_nes(bufnr, client_id)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_get_current_buf() ~= bufnr then return false end
  if not vim.api.nvim_get_mode().mode:match('^n') then return false end

  local attached = attached_copilot_client(client_id, bufnr)
  if attached == nil then return false end

  require('copilot-lsp.nes').request_nes(attached)
  return true
end

function M.setup_copilot_nes(bufnr, client)
  if not nes_enabled() then return end

  local nes = require('copilot-lsp.nes')
  local debounce = require('copilot-lsp.util').debounce
  local nes_group =
    vim.api.nvim_create_augroup(('neocraft_copilot_nes_%d_%d'):format(client.id, bufnr), { clear = true })

  local debounced_request = debounce(function() request_copilot_nes(bufnr, client.id) end, COPILOT_NES_DEBOUNCE_MS)

  vim.api.nvim_create_autocmd('TextChanged', {
    buffer = bufnr,
    group = nes_group,
    desc = 'Request Copilot NES after Normal-mode edits',
    callback = function()
      clear_nes_reshow_budget(bufnr)
      clear_dismissed_nes(bufnr)
      debounced_request()
    end,
  })

  vim.api.nvim_create_autocmd('InsertEnter', {
    buffer = bufnr,
    group = nes_group,
    desc = 'Clear Copilot NES when entering Insert mode',
    callback = function()
      vim.b[bufnr].neocraft_nes_insert_changed = nil
      nes.clear_suggestion(bufnr)
    end,
  })

  vim.api.nvim_create_autocmd('TextChangedI', {
    buffer = bufnr,
    group = nes_group,
    desc = 'Track Insert-mode edits for Copilot NES refreshes',
    callback = function()
      vim.b[bufnr].neocraft_nes_insert_changed = true
      clear_nes_reshow_state(bufnr)
    end,
  })

  vim.api.nvim_create_autocmd('InsertLeave', {
    buffer = bufnr,
    group = nes_group,
    desc = 'Request or revive Copilot NES after Insert mode',
    callback = function()
      local had_insert_changes = vim.b[bufnr].neocraft_nes_insert_changed == true
      vim.b[bufnr].neocraft_nes_insert_changed = nil

      if had_insert_changes then
        clear_nes_reshow_state(bufnr)
        debounced_request()
        return
      end

      if consume_nes_reshow_budget(bufnr) then
        if revive_dismissed_nes(bufnr) then return end
        clear_nes_reshow_state(bufnr)
        return
      end

      clear_dismissed_nes(bufnr)
    end,
  })

  vim.api.nvim_create_autocmd('BufEnter', {
    buffer = bufnr,
    group = nes_group,
    desc = 'Notify Copilot when buffer receives focus',
    callback = function() notify_copilot_did_focus(bufnr, client.id) end,
  })

  vim.api.nvim_create_autocmd('LspDetach', {
    buffer = bufnr,
    group = nes_group,
    desc = 'Clean up Copilot NES lifecycle for detached buffers',
    callback = function(args)
      if not (args.data and args.data.client_id == client.id) then return end

      nes.clear_suggestion(bufnr)
      vim.b[bufnr].neocraft_nes_insert_changed = nil
      clear_nes_reshow_state(bufnr)
      pcall(vim.api.nvim_del_augroup_by_id, nes_group)
    end,
  })

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_get_current_buf() == bufnr then
      notify_copilot_did_focus(bufnr, client.id)
    end
  end)
end

local function normalize_nes_preview_edit(bufnr, edit)
  if type(edit) ~= 'table' or type(edit.newText) ~= 'string' or type(edit.range) ~= 'table' then return edit end

  local normalized = vim.deepcopy(edit)
  local range = normalized.range
  local old_lines = vim.api.nvim_buf_get_lines(bufnr, range.start.line, range['end'].line + 1, false)
  if vim.tbl_isempty(old_lines) then return normalized end

  -- `end = { line = N, character = 0 }` is exclusive and usually means the edit
  -- stops at the start of line `N`, not that line `N` itself should preview as deleted.
  if range.start.line < range['end'].line and range['end'].character == 0 and #old_lines > 1 then
    local last_affected_line = old_lines[#old_lines - 1]
    local untouched_tail_line = old_lines[#old_lines]

    range['end'].line = range['end'].line - 1
    range['end'].character = #last_affected_line

    if not vim.endswith(normalized.newText, '\n') then
      normalized.newText = normalized.newText .. untouched_tail_line
    end

    old_lines = vim.list_slice(old_lines, 1, #old_lines - 1)
  end

  if range.start.character ~= 0 or range.start.line >= range['end'].line then return normalized end

  local new_lines = vim.split(normalized.newText, '\n', { plain = true })
  if #old_lines < 2 or #new_lines < 2 then return normalized end

  local trim_count = 0
  while trim_count < #old_lines - 1 and trim_count < #new_lines - 1 do
    if old_lines[trim_count + 1] ~= new_lines[trim_count + 1] then break end
    trim_count = trim_count + 1
  end

  if trim_count == 0 then return normalized end

  range.start.line = range.start.line + trim_count
  normalized.newText = table.concat(vim.list_slice(new_lines, trim_count + 1), '\n')
  return normalized
end

local function patch_copilot_nes_preview()
  local nes_ui = require('copilot-lsp.nes.ui')
  if nes_ui._neocraft_preview_patch_applied == true then return end

  local original_calculate_preview = nes_ui._calculate_preview
  nes_ui._calculate_preview = function(bufnr, edit)
    return original_calculate_preview(bufnr, normalize_nes_preview_edit(bufnr, edit))
  end

  nes_ui._neocraft_preview_patch_applied = true
end

local function cache_dismissed_nes(bufnr, edit)
  if type(edit) ~= 'table' then
    clear_dismissed_nes(bufnr)
    return
  end

  vim.b[bufnr].neocraft_dismissed_nes = vim.deepcopy(edit)
end

local function prime_nes_reshow_budget(bufnr)
  if COPILOT_NES_RESHOW_AFTER_DISMISS_COUNT > 0 then
    vim.b[bufnr].neocraft_nes_reshow_budget = COPILOT_NES_RESHOW_AFTER_DISMISS_COUNT
  else
    clear_nes_reshow_budget(bufnr)
  end
end

local function same_nes(a, b)
  if type(a) ~= 'table' or type(b) ~= 'table' then return false end
  return vim.deep_equal(a, b)
end

function M.dismiss_nes(bufnr)
  if not nes_enabled() then return false end

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local state = vim.b[bufnr].nes_state
  if state == nil then return false end

  local cached = dismissed_nes(bufnr)
  if not same_nes(state, cached) then
    prime_nes_reshow_budget(bufnr)
    cache_dismissed_nes(bufnr, state)
  end

  require('copilot-lsp.nes').clear_suggestion(bufnr)
  return true
end

if nes_enabled() then patch_copilot_nes_preview() end

-- ┌───────────────────────────────────────────┐
-- │ On attach LSP setup & mappings            │
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

local function inline_completions_enabled() return vim.g.enable_inline_completions == true end

Lib.autocmd('LspAttach', {
  group = group,
  desc = 'Configure buffer-local LSP mappings and clues',
  callback = function(args)
    local bufnr = args.buf
    local client_id = args.data and args.data.client_id
    local client = client_id and vim.lsp.get_client_by_id(client_id) or nil
    if not client then return end

    vim.bo[bufnr].omnifunc = 'v:lua.MiniCompletion.completefunc_lsp'

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
      if vim.b[bufnr].neocraft_inlay_hints_enabled == nil then vim.b[bufnr].neocraft_inlay_hints_enabled = true end
    end

    if client:supports_method(Methods.textDocument_codeLens, bufnr) then
      if vim.b[bufnr].neocraft_codelens_enabled == nil then vim.b[bufnr].neocraft_codelens_enabled = true end
    end

    if
      client:supports_method(Methods.textDocument_inlayHint, bufnr)
      or client:supports_method(Methods.textDocument_codeLens, bufnr)
    then
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(bufnr) then M.reset_buffer_annotations(bufnr) end
      end, 0)
    end

    if
      inline_completions_enabled()
      and is_copilot_client(client)
      and client:supports_method(Methods.textDocument_inlineCompletion, bufnr)
    then
      vim.lsp.inline_completion.enable(true, { client_id = client.id })

      map('i', '<M-]>', M.trigger_or_cycle_inline_completion(bufnr), 'Next / Retrigger inline completion')
      map('i', '<M-[>', function() vim.lsp.inline_completion.select({ count = -1 }) end, 'Previous inline completion')
    end

    if is_copilot_client(client) then M.setup_copilot_nes(bufnr, client) end

    refresh_clue_triggers(bufnr)
  end,
})

return M
