local map = vim.keymap.set

-- ┌───────────────────────────────────────────┐
-- │ Helpers                                   │
-- └───────────────────────────────────────────┘

local function nmap(lhs, rhs, desc) map('n', lhs, rhs, { desc = desc }) end

local function tmap(lhs, rhs, desc) map('t', lhs, rhs, { desc = desc }) end

local function goto_diagnostic(next, severity)
  local go = next and vim.diagnostic.goto_next or vim.diagnostic.goto_prev
  local level = severity and vim.diagnostic.severity[severity] or nil

  return function() go({ severity = level }) end
end

-- ┌───────────────────────────────────────────┐
-- │ Global Key Mappings                       │
-- └───────────────────────────────────────────┘

nmap('<Esc>', '<Cmd>nohlsearch<CR>', 'Clear search highlight')
nmap('<C-h>', '<C-w><C-h>', 'Move focus left')
nmap('<C-j>', '<C-w><C-j>', 'Move focus down')
nmap('<C-k>', '<C-w><C-k>', 'Move focus up')
nmap('<C-l>', '<C-w><C-l>', 'Move focus right')
nmap(']e', goto_diagnostic(true, 'ERROR'), 'Next diagnostic error')
nmap('[e', goto_diagnostic(false, 'ERROR'), 'Prev diagnostic error')
nmap('<leader>q', vim.diagnostic.setloclist, 'Open diagnostics list')

tmap('<Esc><Esc>', '<C-\\><C-n>', 'Exit terminal mode')

return {}
