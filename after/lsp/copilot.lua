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
    spec = { 'lsp', root.spec[2] },
    all = false,
  })

  return detected[1] and detected[1].paths[1] or file_dir(bufnr) or root.cwd()
end

return {
  root_dir = function(bufnr, on_dir) on_dir(copilot_root(bufnr)) end,
  settings = {
    nextEditSuggestions = {
      enabled = vim.g.enable_NES == true,
    },
  },
}
