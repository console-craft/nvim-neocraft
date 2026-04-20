-- Overrides the default `root_dir` logic from the default oxlint LSP config provided by `nvim-lspconfig`.
--
--  * Only starts Oxlint when the buffer lives in a project with an explicit Oxlint config.
--  * Refuses to attach when the same project also declares ESLint config to avoid overlapping linters.
--  * Refuses to attach when the same project also declares Biome config to avoid overlapping JS tooling.
--
-- DOCS: https://github.com/neovim/nvim-lspconfig/blob/master/lsp/oxlint.lua

-- ┌───────────────────────────────────────────┐
-- │ Setup                                     │
-- └───────────────────────────────────────────┘

local eslint_markers = {
  '.eslintrc',
  '.eslintrc.js',
  '.eslintrc.cjs',
  '.eslintrc.yaml',
  '.eslintrc.yml',
  '.eslintrc.json',
  'eslint.config.js',
  'eslint.config.mjs',
  'eslint.config.cjs',
  'eslint.config.ts',
  'eslint.config.mts',
  'eslint.config.cts',
}

local biome_markers = {
  'biome.json',
  'biome.jsonc',
  '.biome.json',
  '.biome.jsonc',
}

local oxlint_markers = {
  '.oxlintrc.json',
  '.oxlintrc.jsonc',
  'oxlint.config.ts',
}

local root_markers = {
  'package-lock.json',
  'yarn.lock',
  'pnpm-lock.yaml',
  'bun.lockb',
  'bun.lock',
  'deno.lock',
  '.git',
}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local function read_json(path)
  local file = io.open(path, 'r')
  if not file then return nil end

  local content = file:read('*all')
  file:close()

  local ok, decoded = pcall(vim.json.decode, content)
  return ok and decoded or nil
end

local function package_has_key(package_json, key)
  local decoded = read_json(package_json)
  return type(decoded) == 'table' and decoded[key] ~= nil
end

local function project_root(bufnr) return vim.fs.root(bufnr, root_markers) or vim.fn.getcwd() end

local function has_config(bufnr, markers, package_key)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local root_dir = project_root(bufnr)
  local stop = vim.fs.dirname(root_dir)

  if vim.fs.find(markers, { path = filename, type = 'file', limit = 1, upward = true, stop = stop })[1] then
    return true, root_dir
  end

  if type(package_key) ~= 'string' then return false, root_dir end

  local package_jsons = vim.fs.find(
    { 'package.json' },
    { path = filename, type = 'file', limit = 32, upward = true, stop = stop }
  )
  for _, package_json in ipairs(package_jsons) do
    if package_has_key(package_json, package_key) then return true, root_dir end
  end

  return false, root_dir
end

-- ┌───────────────────────────────────────────┐
-- │ LSP config                                │
-- └───────────────────────────────────────────┘

return {
  root_dir = function(bufnr, on_dir)
    local has_oxlint, root_dir = has_config(bufnr, oxlint_markers)
    if not has_oxlint then return end
    if select(1, has_config(bufnr, eslint_markers, 'eslintConfig')) then return end
    if select(1, has_config(bufnr, biome_markers, 'biomejs')) then return end
    on_dir(root_dir)
  end,
}
