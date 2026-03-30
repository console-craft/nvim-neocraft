assert(vim.pack, 'Neocraft requires Neovim 0.12+ with vim.pack support')

local M = {}

local registry = {}
local group_by_plugin = {}

-- ┌───────────────────────────────────────────┐
-- │ Add Plugin                                │
-- └───────────────────────────────────────────┘

local function plugin_name(spec)
  if type(spec) == 'string' then
    local src = spec:gsub('/+$', '')
    return src:match('/([^/]+)%.git$') or src:match('/([^/]+)$') or src
  end

  if spec.name and spec.name ~= '' then return spec.name end

  local src = assert(spec.src, 'Neocraft vim.pack specs must include `src`')
  src = src:gsub('/+$', '')

  return src:match('/([^/]+)%.git$') or src:match('/([^/]+)$') or src
end

local function normalize_specs(specs)
  if vim.islist(specs) then return specs end

  return { specs }
end

function M.add(group_name, specs, opts)
  assert(type(group_name) == 'string' and group_name ~= '', 'Neocraft pack group name must be a non-empty string')

  specs = normalize_specs(specs)
  registry[group_name] = registry[group_name] or {}

  for _, spec in ipairs(specs) do
    local name = plugin_name(spec)
    local existing_group = group_by_plugin[name]

    if existing_group and existing_group ~= group_name then
      error(string.format("Plugin '%s' is already registered in group '%s'", name, existing_group))
    end

    if not existing_group then
      group_by_plugin[name] = group_name
      table.insert(registry[group_name], vim.deepcopy(spec))
    end
  end

  vim.pack.add(specs, opts)
  return specs
end

-- ┌───────────────────────────────────────────┐
-- │ Show Plugin Groups                        │
-- └───────────────────────────────────────────┘

local function sorted_keys(tbl)
  local keys = vim.tbl_keys(tbl)
  table.sort(keys)
  return keys
end

local function pack_buf_id()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == 'neocraft-pack' then return buf end
  end

  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(buf, 'neocraft://pack/summary')
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = 'neocraft-pack'
  vim.bo[buf].modifiable = false
  vim.bo[buf].swapfile = false

  return buf
end

local function refresh_pack_buffer(buf)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, M.summary_lines())
  vim.bo[buf].modifiable = false
end

function M.summary_lines()
  local lines = {
    'Neocraft vim.pack',
    '',
    'Lockfile: ' .. vim.fs.joinpath(vim.fn.stdpath('config'), 'nvim-pack-lock.json'),
    'Install dir: ' .. vim.fs.joinpath(vim.fn.stdpath('data'), 'site', 'pack', 'core', 'opt'),
    'Plugin groups:',
  }

  if vim.tbl_isempty(registry) then
    table.insert(lines, '')
    table.insert(lines, 'No plugin groups registered yet.')
    return lines
  end

  for _, group_name in ipairs(sorted_keys(registry)) do
    table.insert(lines, '')
    table.insert(lines, group_name .. ':')

    for _, spec in ipairs(registry[group_name]) do
      table.insert(lines, ' - ' .. plugin_name(spec))
    end
  end

  return lines
end

function M.show_pack()
  local buf = pack_buf_id()

  refresh_pack_buffer(buf)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

-- ┌───────────────────────────────────────────┐
-- │ Misc                                      │
-- └───────────────────────────────────────────┘

function M.registry() return vim.deepcopy(registry) end

function M.group(name) return vim.deepcopy(registry[name] or {}) end

function M.on_changed(plugin_name_value, kinds, callback, desc)
  kinds = type(kinds) == 'string' and { kinds } or kinds

  local group = Lib.augroup('pack')

  return Lib.autocmd('PackChanged', {
    group = group,
    desc = desc or ('Handle vim.pack changes for ' .. plugin_name_value),
    callback = function(ev)
      local data = ev.data or {}
      local spec = data.spec or {}

      if spec.name ~= plugin_name_value then return end
      if kinds and not vim.tbl_contains(kinds, data.kind) then return end

      if not data.active then vim.cmd.packadd(spec.name) end
      callback(ev)
    end,
  })
end

return M
