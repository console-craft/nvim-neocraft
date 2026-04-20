-- Provide Python-specific LSP helpers.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

-- Return the first attached Ruff client for the target buffer.
---@param bufnr? integer
---@return vim.lsp.Client?
local function ruff_client(bufnr) return vim.lsp.get_clients({ bufnr = bufnr or 0, name = 'ruff' })[1] end

-- Run a callback only when Ruff is attached to the target buffer.
---@generic T
---@param bufnr? integer
---@param callback fun(client: vim.lsp.Client, bufnr: integer): T?
---@return T?
local function with_ruff_client(bufnr, callback)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local client = ruff_client(bufnr)
  if not client then
    vim.notify('ruff is not attached to the current buffer', vim.log.levels.INFO)
    return nil
  end

  return callback(client, bufnr)
end

-- Apply a Ruff-provided code action in the current buffer.
---@param kind string
---@param bufnr? integer
local function ruff_code_action(kind, bufnr)
  with_ruff_client(bufnr, function(client)
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

-- Organize Python imports through Ruff.
---@param bufnr? integer
function M.python_organize_imports(bufnr) return ruff_code_action('source.organizeImports.ruff', bufnr) end

-- Open the virtual environment picker for Python buffers.
function M.python_select_venv()
  if vim.bo.filetype ~= 'python' then
    vim.notify('Python virtual environment selection is only available in Python buffers', vim.log.levels.INFO)
    return
  end

  vim.cmd.VenvSelect()
end

return M
