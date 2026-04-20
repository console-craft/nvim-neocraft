local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

-- Return attached Copilot clients for a buffer.
local function copilot_clients(bufnr) return vim.lsp.get_clients({ bufnr = bufnr or 0, name = 'copilot' }) end

-- Check whether inline completions are enabled globally.
local function inline_completions_enabled() return vim.g.enable_inline_completions == true end

-- Reset inline completion state for a buffer and re-enable it on the next tick.
local function reset_inline_completion(bufnr)
  if not inline_completions_enabled() then return false end

  bufnr = bufnr or 0
  local resolved = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  if vim.tbl_isempty(copilot_clients(resolved)) then return false end

  vim.lsp.inline_completion.enable(false, { bufnr = resolved })

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(resolved) then vim.lsp.inline_completion.enable(true, { bufnr = resolved }) end
  end)

  return true
end

-- Check whether the completion menu has an actively selected item.
local function completion_item_selected() return vim.fn.complete_info({ 'selected' }).selected ~= -1 end

-- Accept a selected completion item or fall back to newline.
function M.accept_completion_or_cr()
  if vim.fn.pumvisible() == 1 and completion_item_selected() then
    reset_inline_completion(0)
    return vim.keycode('<C-y>')
  end

  return vim.keycode('<CR>')
end

-- Close the completion menu before inserting a newline.
function M.close_completion_and_cr()
  if vim.fn.pumvisible() == 1 then return vim.keycode('<C-e><CR>') end
  return vim.keycode('<CR>')
end

-- Dismiss inline completion or fall back to the literal key.
function M.dismiss_inline_completion_or_ctrl_right_square()
  if reset_inline_completion(0) then return '' end
  return vim.keycode('<C-]>')
end

-- Sync inline completion enablement with snippet state for a buffer.
local function sync_inline_completion_state(bufnr)
  if not inline_completions_enabled() then
    if not vim.tbl_isempty(copilot_clients(bufnr)) then vim.lsp.inline_completion.enable(false, { bufnr = bufnr }) end
    return
  end

  if vim.tbl_isempty(copilot_clients(bufnr)) then return end
  vim.lsp.inline_completion.enable(not vim.snippet.active(), { bufnr = bufnr })
end

-- Sync both completion backends against current snippet activity.
local function sync_snippet_completion_state(bufnr)
  bufnr = bufnr or 0
  local snippet_active = vim.snippet.active()

  if snippet_active then
    vim.b[bufnr].minicompletion_disable = true
  else
    vim.b[bufnr].minicompletion_disable = nil
  end

  sync_inline_completion_state(bufnr)
end

-- Close the popup completion menu if it is visible.
local function close_completion_menu()
  if vim.fn.pumvisible() == 1 then vim.api.nvim_feedkeys(vim.keycode('<C-e>'), 'in', false) end
end

-- ┌───────────────────────────────────────────┐
-- │ Snippet state management                  │
-- └───────────────────────────────────────────┘

local snippet_completion_group = Lib.augroup('snippet_completion')

Lib.autocmd({ 'InsertEnter', 'CursorMovedI', 'ModeChanged' }, {
  group = snippet_completion_group,
  desc = 'Disable automatic completion while editing snippet placeholders',
  callback = function(args)
    local bufnr = args.buf ~= 0 and args.buf or vim.api.nvim_get_current_buf()
    sync_snippet_completion_state(bufnr)
  end,
})

Lib.autocmd('InsertCharPre', {
  group = snippet_completion_group,
  desc = 'Cancel pending automatic completion inside active snippet placeholders',
  callback = function(args)
    local bufnr = args.buf ~= 0 and args.buf or vim.api.nvim_get_current_buf()
    if not vim.snippet.active() then return end

    require('mini.completion').stop({ 'completion', 'info' })
    vim.b[bufnr].minicompletion_disable = true
  end,
})

Lib.autocmd('InsertLeave', {
  group = snippet_completion_group,
  desc = 'Clear snippet completion state on InsertLeave',
  callback = function(args)
    local bufnr = args.buf ~= 0 and args.buf or vim.api.nvim_get_current_buf()
    vim.b[bufnr].minicompletion_disable = nil
  end,
})

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Return a literal Tab key sequence.
function M.insert_literal_tab() return '<Tab>' end

-- Close the completion menu or accept the active inline suggestion to end-of-line.
function M.close_completion_or_accept_inline_completion_to_eol()
  if vim.fn.pumvisible() == 1 then return vim.keycode('<C-e>') end
  if require('neocraft.features.lsp').accept_inline_completion_to_eol() then return '' end
  return vim.keycode('<C-e>')
end

-- Manually trigger mini.completion and then resync snippet-aware completion state.
function M.trigger_manual_completion()
  local bufnr = vim.api.nvim_get_current_buf()

  vim.b[bufnr].minicompletion_disable = nil

  require('mini.completion').complete_twostage()

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then sync_snippet_completion_state(bufnr) end
  end)
end

-- Accept inline completion, jump to the next snippet stop, or insert a tab.
function M.accept_inline_completion_or_snippet_jump_next_or_tab()
  close_completion_menu()

  if vim.snippet.active({ direction = 1 }) then return '<Cmd>lua vim.snippet.jump(1)<CR>' end
  if vim.snippet.active() then return '<Tab>' end

  if vim.lsp.inline_completion.get() then return '' end

  return '<Tab>'
end

-- Jump to the previous snippet stop or fall back to Shift-Tab.
function M.snippet_jump_prev_or_stab()
  close_completion_menu()
  if vim.snippet.active({ direction = -1 }) then return '<Cmd>lua vim.snippet.jump(-1)<CR>' end
  return '<S-Tab>'
end

return M
