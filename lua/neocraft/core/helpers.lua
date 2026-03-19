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

return M
