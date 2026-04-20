-- Merge language profiles into shared server, tool, and formatter maps.

---@class neocraft.lang.ProjectFormatterEntry
---@field project? string
---@field fallback? string[]

---@alias neocraft.lang.FormatterEntry string[]|neocraft.lang.ProjectFormatterEntry

---@class neocraft.lang.Profile
---@field servers? table<string, table>
---@field tools? string[]
---@field formatters_by_ft? table<string, neocraft.lang.FormatterEntry>

---@class neocraft.lang.NamedProfile
---@field name string
---@field spec neocraft.lang.Profile

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Profiles                                  │
-- └───────────────────────────────────────────┘

---@type neocraft.lang.NamedProfile[]
local profiles = {
  { name = 'base', spec = require('neocraft.lang.base') },
  { name = 'typescript', spec = require('neocraft.lang.typescript') },
  { name = 'python', spec = require('neocraft.lang.python') },
}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

-- Merge a list of language profile maps associated to a key into a single map, checking for duplicate entries.
---@param key 'servers'|'formatters_by_ft'
---@return table<string, any>
local function merge_map(key)
  local merged = {}

  for _, profile in ipairs(profiles) do
    for name, value in pairs(profile.spec[key] or {}) do
      if merged[name] ~= nil then
        error(string.format('Duplicate %s entry %q in language profile %q', key, name, profile.name))
      end

      merged[name] = type(value) == 'table' and vim.deepcopy(value) or value
    end
  end

  return merged
end

-- Merge a list of language profile tool lists into a single list, checking for duplicate entries.
---@return string[]
local function merge_tools()
  local merged = {}
  local seen = {}

  for _, profile in ipairs(profiles) do
    for _, tool in ipairs(profile.spec.tools or {}) do
      if not seen[tool] then
        seen[tool] = true
        table.insert(merged, tool)
      end
    end
  end

  return merged
end

-- ┌───────────────────────────────────────────┐
-- │ Merged profile maps                       │
-- └───────────────────────────────────────────┘

M.servers = merge_map('servers')
M.tools = merge_tools()
M.formatters_by_ft = merge_map('formatters_by_ft')

return M
