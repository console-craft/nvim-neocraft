local M = {}

function M.now(fn) return fn() end

function M.later(fn) return vim.schedule(fn) end

function M.augroup(name, opts)
  opts = opts or {}

  return vim.api.nvim_create_augroup('neocraft-' .. name, {
    clear = opts.clear ~= false,
  })
end

function M.autocmd(event, opts) return vim.api.nvim_create_autocmd(event, opts) end

function M.goto_diagnostic(next, severity)
  local go = next and vim.diagnostic.goto_next or vim.diagnostic.goto_prev
  local level = severity and vim.diagnostic.severity[severity] or nil

  return function() go({ severity = level }) end
end

return M
