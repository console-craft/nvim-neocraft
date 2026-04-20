-- Provide Copilot LSP helpers and inline completion helpers.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

-- Check whether the attached client is Copilot.
local function is_copilot_client(client) return client.name == 'copilot' end

-- Return the first attached Copilot client for the target buffer.
local function copilot_client(bufnr) return vim.lsp.get_clients({ bufnr = bufnr or 0, name = 'copilot' })[1] end

-- Run a buffer-local Copilot command when it is available.
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

-- Find the first index where two strings stop sharing the same prefix.
local function common_prefix_end(a, b)
  local index, length_a, length_b = 1, #a, #b
  while index <= length_a and index <= length_b and a:sub(index, index) == b:sub(index, index) do
    index = index + 1
  end
  return index
end

-- Extract the visible inline completion text relative to the current buffer state.
local function parse_visible_inline_text(item, bufnr, winid)
  bufnr = vim._resolve_bufnr(bufnr)

  if type(item.insert_text) ~= 'string' then return nil end

  if not (winid and vim.api.nvim_win_is_valid(winid)) then return nil end
  if vim.api.nvim_win_get_buf(winid) ~= bufnr then return nil end

  local start_row, start_col
  if item.range then
    start_row, start_col = item.range:to_extmark()
  else
    local cursor = vim.api.nvim_win_get_cursor(winid)
    start_row, start_col = cursor[1] - 1, cursor[2]
  end

  local line_text = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
  if type(line_text) ~= 'string' or #line_text < start_col then return nil end

  local suggested_lines = vim.split(item.insert_text, '\n', { plain = true })
  local first_suggested_line = suggested_lines[1] or ''

  local skip = common_prefix_end(line_text:sub(start_col + 1), first_suggested_line)

  local cursor = vim.api.nvim_win_get_cursor(winid)
  local cursor_row, cursor_col = cursor[1] - 1, cursor[2]
  if start_row == cursor_row then skip = math.max(skip, cursor_col - start_col + 1) end

  return {
    existing_line_text = first_suggested_line:sub(1, skip - 1),
    append_to_current_line_text = first_suggested_line:sub(skip),
    next_suggested_line_text = suggested_lines[2],
  }
end

-- Trim an inline completion item so acceptance stops at the end of the current line.
local function build_eol_item(item, bufnr, winid)
  local parsed = parse_visible_inline_text(item, bufnr, winid)
  if parsed == nil then return nil end

  local patched = vim.deepcopy(item)
  local insert_text = parsed.existing_line_text .. parsed.append_to_current_line_text

  if parsed.next_suggested_line_text ~= nil then
    insert_text = insert_text .. '\n' .. (parsed.next_suggested_line_text:match('^%s*') or '')
  end

  patched.insert_text = insert_text
  return patched
end

-- Check whether an inline completion ghost text is currently visible.
local function inline_completion_visible(bufnr)
  local ns = vim.api.nvim_get_namespaces()['nvim.lsp.inline_completion']
  if ns == nil then return false end

  return #vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { limit = 1 }) > 0
end

-- Access Neovim's active inline completion controller for a buffer.
local function inline_completor(bufnr)
  local _, completor = debug.getupvalue(vim.lsp.inline_completion.get, 1)
  if type(completor) ~= 'table' or type(completor.active) ~= 'table' then return nil end
  return completor.active[bufnr]
end

-- Abort and immediately request a fresh inline completion.
local function retrigger_inline_completion(bufnr)
  local completor = inline_completor(bufnr)
  if completor == nil or type(completor.request) ~= 'function' then return false end

  completor:abort()
  completor:request(vim.lsp.protocol.InlineCompletionTriggerKind.Invoked)
  return true
end

-- Ask for confirmation before signing out of Copilot.
local function confirm_copilot_sign_out() return vim.fn.confirm('Sign out of Copilot?', '&Yes\n&No', 2) == 1 end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Trigger Copilot sign-in for the target buffer.
function M.copilot_sign_in(bufnr) run_copilot_command('LspCopilotSignIn', bufnr) end

-- Trigger Copilot sign-out for the target buffer.
function M.copilot_sign_out(bufnr)
  if not confirm_copilot_sign_out() then return end
  run_copilot_command('LspCopilotSignOut', bufnr)
end

-- Accept the visible inline completion only through the end of the current line.
function M.accept_inline_completion_to_eol(bufnr)
  bufnr = vim._resolve_bufnr(bufnr)
  local winid = vim.api.nvim_get_current_win()

  return vim.lsp.inline_completion.get({
    bufnr = bufnr,
    on_accept = function(item) return build_eol_item(item, bufnr, winid) end,
  })
end

-- Cycle visible inline completions or retrigger them when none are shown.
function M.trigger_or_cycle_inline_completion(bufnr)
  return function()
    if inline_completion_visible(bufnr) then
      vim.lsp.inline_completion.select({ bufnr = bufnr })
      return
    end

    retrigger_inline_completion(bufnr)
  end
end

M.is_copilot_client = is_copilot_client

return M
