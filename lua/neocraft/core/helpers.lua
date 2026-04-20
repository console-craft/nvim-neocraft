-- Reusable helper functions for Neocraft.

local M = {}

-- Run a function immediately and return its result.
function M.now(fn) return fn() end

-- Schedule a function to run on the next event loop tick.
function M.later(fn) return vim.schedule(fn) end

-- Create a named autocommand group with optional clearing of existing autocommands.
function M.augroup(name, opts)
  opts = opts or {}

  return vim.api.nvim_create_augroup('neocraft-' .. name, {
    clear = opts.clear ~= false,
  })
end

-- Create an autocommand for the specified event(s) with the given options.
function M.autocmd(event, opts) return vim.api.nvim_create_autocmd(event, opts) end

return M
