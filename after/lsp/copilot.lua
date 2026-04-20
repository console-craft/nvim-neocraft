-- Overrides the default `root_dir` logic from nvim-lspconfig's Copilot config.
--
--  * Uses Neocraft's shared root detection so Copilot follows attached LSP workspaces before falling back to local markers.
--  * Falls back to the buffer's directory, then the current working directory, when no project root can be inferred.
--
-- DOCS: https://github.com/neovim/nvim-lspconfig/blob/master/lsp/copilot.lua

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local root = require('neocraft.core.root')

local function file_dir(bufnr)
  local bufpath = root.bufpath(bufnr)
  if bufpath == nil then return nil end
  if vim.fn.isdirectory(bufpath) == 1 then return bufpath end
  return vim.fs.dirname(bufpath)
end

local function copilot_root(bufnr)
  local detected = root.detect({
    buf = bufnr,
    spec = { 'lsp', root.project_markers },
    all = false,
  })

  return detected[1] and detected[1].paths[1] or file_dir(bufnr) or root.cwd()
end

-- ┌───────────────────────────────────────────┐
-- │ LSP config                                │
-- └───────────────────────────────────────────┘

return {
  root_dir = function(bufnr, on_dir) on_dir(copilot_root(bufnr)) end,
}
