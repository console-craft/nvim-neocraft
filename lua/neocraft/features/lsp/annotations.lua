-- Manage temporary visibility and user toggles for LSP buffer annotations.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local group = Lib.augroup('lsp-annotations')
local Methods = vim.lsp.protocol.Methods

-- Checks if the mini.diff overlay is active for the given buffer, which can temporarily disable annotations.
local function mini_diff_overlay_active(bufnr)
  local ok, mini_diff = pcall(require, 'mini.diff')
  if not ok then return false end

  local ok_data, data = pcall(mini_diff.get_buf_data, bufnr)
  return ok_data and data ~= nil and data.overlay == true
end

-- Checks if the given buffer is currently visible inside an active Diffview tab.
local function diffview_buffer_visible(bufnr)
  local ok, lib = pcall(require, 'diffview.lib')
  if not ok then return false end

  local view = lib.get_current_view()
  if view == nil or type(view.tabpage) ~= 'number' or not vim.api.nvim_tabpage_is_valid(view.tabpage) then
    return false
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(view.tabpage)) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then return true end
  end

  return false
end

-- Determines if annotations should be temporarily disabled for the given buffer, based on diff overlays or Insert mode.
local function annotations_temporarily_disabled(bufnr)
  return mini_diff_overlay_active(bufnr)
    or diffview_buffer_visible(bufnr)
    or vim.api.nvim_get_mode().mode:match('^i') ~= nil
end

-- Checks if any attached LSP client for the given buffer supports the specified method.
local function any_client_supports_method(bufnr, method)
  return #vim.lsp.get_clients({ bufnr = bufnr, method = method }) > 0
end

-- Resets inlay hints for the specified buffer based on user settings and temporary conditions.
local function reset_inlay_hints(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not any_client_supports_method(bufnr, Methods.textDocument_inlayHint) then return end

  local should_enable = vim.b[bufnr].neocraft_inlay_hints_enabled == true
    and not annotations_temporarily_disabled(bufnr)
  vim.lsp.inlay_hint.enable(should_enable, { bufnr = bufnr })
end

-- Resets code lens for the specified buffer based on user settings and temporary conditions.
local function reset_codelens(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not any_client_supports_method(bufnr, Methods.textDocument_codeLens) then return end

  local should_enable = vim.b[bufnr].neocraft_codelens_enabled == true and not annotations_temporarily_disabled(bufnr)
  vim.lsp.codelens.enable(should_enable, { bufnr = bufnr })
end

-- Hides all LSP annotations for the specified buffer (when entering Insert mode or when a diff overlay is active).
local function hide_buffer_annotations(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if any_client_supports_method(bufnr, Methods.textDocument_inlayHint) then
    vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
  end
  if any_client_supports_method(bufnr, Methods.textDocument_codeLens) then
    vim.lsp.codelens.enable(false, { bufnr = bufnr })
  end
end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Reset LSP annotations for the specified buffer, based on user settings and temporary conditions.
function M.reset_buffer_annotations(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  reset_inlay_hints(bufnr)
  reset_codelens(bufnr)
end

-- Toggle LSP inlay hints display for the current buffer.
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

-- Toggle LSP code lens display for the current buffer.
function M.toggle_codelens()
  local bufnr = vim.api.nvim_get_current_buf()
  if not any_client_supports_method(bufnr, Methods.textDocument_codeLens) then
    vim.notify('No attached LSP client supports codelens for this buffer', vim.log.levels.INFO)
    return
  end

  local enabled = vim.b[bufnr].neocraft_codelens_enabled == true
  vim.b[bufnr].neocraft_codelens_enabled = not enabled
  reset_codelens(bufnr)
  vim.api.nvim_echo({ { (enabled and 'Disabled: ' or 'Enabled: ') .. 'codelens', 'Normal' } }, false, {})
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

Lib.autocmd({ 'BufEnter', 'WinEnter' }, {
  group = group,
  desc = 'Refresh annotations for entered buffers',
  callback = function(args) M.reset_buffer_annotations(args.buf) end,
})

return M
