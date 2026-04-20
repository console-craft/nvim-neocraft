-- Neocraft's wrapper around vim.pack, providing plugin grouping and a summary buffer.

---@alias neocraft.pack.Spec string|table
---@alias neocraft.pack.SpecList neocraft.pack.Spec[]

assert(vim.pack, 'Neocraft requires Neovim 0.12+ with vim.pack support')

local M = {}

local registry = {}

-- ┌───────────────────────────────────────────┐
-- │ Add Plugin                                │
-- └───────────────────────────────────────────┘

local group_by_plugin = {}

-- Extract a plugin name from a vim.pack spec.
---@param spec neocraft.pack.Spec
---@return string
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

-- Normalize a single spec or a list of specs into a list of specs.
---@param specs neocraft.pack.Spec|neocraft.pack.SpecList
---@return neocraft.pack.SpecList
local function normalize_specs(specs)
  if type(specs) == 'table' and vim.islist(specs) then return specs end

  return { specs }
end

-- Add plugins to a named unique group and register them with vim.pack, returning the normalized specs.
---@param group_name string
---@param specs neocraft.pack.Spec|neocraft.pack.SpecList
---@param opts? table
---@return neocraft.pack.SpecList
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
      table.insert(registry[group_name], type(spec) == 'table' and vim.deepcopy(spec) or spec)
    end
  end

  vim.pack.add(specs, opts)
  return specs
end

-- ┌───────────────────────────────────────────┐
-- │ Show Plugin Groups                        │
-- └───────────────────────────────────────────┘

-- Return a sorted list of the keys in a table.
---@param tbl table<string, any>
---@return string[]
local function sorted_keys(tbl)
  local keys = vim.tbl_keys(tbl)
  table.sort(keys)
  return keys
end

-- Generate lines summarizing the current plugin groups and their plugins.
---@return string[]
local function summary_lines()
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

-- Refresh the contents of the pack summary buffer with the current plugin groups and their plugins.
---@param buf integer
local function refresh_pack_buffer(buf)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, summary_lines())
  vim.bo[buf].modifiable = false
end

-- Find or create a buffer for showing the pack summary, setting it up with the appropriate options and triggers.
---@return integer
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

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then return end

    local ok, clue = pcall(require, 'mini.clue')
    if not ok then return end

    clue.ensure_buf_triggers(buf)
  end)

  return buf
end

-- Open a buffer showing the current plugin groups and their plugins, with installation status.
function M.show_pack()
  local buf = pack_buf_id()

  refresh_pack_buffer(buf)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

-- ┌───────────────────────────────────────────┐
-- │ Update Plugins                            │
-- └───────────────────────────────────────────┘

-- Trigger vim.pack to check for updates.
function M.update() vim.pack.update() end

-- ┌───────────────────────────────────────────┐
-- │ Misc                                      │
-- └───────────────────────────────────────────┘

-- Register a callback to be triggered when plugins are added, updated, or removed, with optional name and kind filters.
---@param plugin_name_value string
---@param kinds? string|string[]
---@param callback fun(ev: table)
---@param desc? string
---@return integer
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
      if
        kinds and not vim.tbl_contains(kinds --[[@as string[] ]], data.kind)
      then
        return
      end

      if not data.active then vim.cmd.packadd(spec.name) end
      callback(ev)
    end,
  })
end

return M
