local M = {}

local uv = vim.uv or vim.loop

local function executable(name, opts)
  local message = "Found executable: '" .. name .. "'"
  if vim.fn.executable(name) == 1 then
    vim.health.ok(message)
    return
  end

  message = "Missing executable: '" .. name .. "'"
  if opts and opts.required then
    vim.health.error(message)
  else
    vim.health.warn(message)
  end
end

local function file_exists(path) return uv.fs_stat(path) ~= nil end

local function config_file(relative_path)
  local path = vim.fs.joinpath(vim.fn.stdpath('config'), relative_path)
  if file_exists(path) then
    vim.health.ok("Found file: '" .. relative_path .. "'")
    return
  end

  vim.health.warn("Missing file: '" .. relative_path .. "'")
end

function M.check()
  vim.health.start('Core executables')
  executable('git', { required = true })
  executable('rg', { required = true })
  executable('make')
  executable('unzip')
  vim.health.info('These executables are used by Neocraft itself and are required for normal operation.')

  vim.health.start('Neocraft runtime')
  local version = vim.version()
  local version_string = string.format('%d.%d.%d', version.major, version.minor, version.patch)
  if vim.fn.has('nvim-0.12') == 1 then
    vim.health.ok("Neovim version is '" .. version_string .. "'")
  else
    vim.health.error("Neocraft requires Neovim 0.12+, found '" .. version_string .. "'")
  end
  if type(vim.pack) == 'table' and type(vim.pack.add) == 'function' then
    vim.health.ok('vim.pack is available')
  else
    vim.health.error('vim.pack is unavailable; Neocraft requires Neovim 0.12 pack support')
  end
  vim.health.info('For deeper runtime diagnostics, use :checkhealth vim.lsp and :checkhealth vim.treesitter.')

  vim.health.start('Repo files')
  config_file('nvim-pack-lock.json')
  config_file('scripts/checks.sh')
  config_file('scripts/live_luals.lua')
  vim.health.info(
    'These files describe the checked-in Neocraft repository and are mainly useful when developing or verifying this config.'
  )

  vim.health.start('Maintainer tools')
  executable('luacheck')
  executable('stylua')
  executable('lua-language-server')
  vim.health.info('These tools back scripts/checks.sh and are mainly needed when developing Neocraft itself.')
end

return M
