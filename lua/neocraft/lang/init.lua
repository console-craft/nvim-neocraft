local M = {}

local profiles = {
  { name = 'authoring', spec = require('neocraft.lang.authoring') },
  { name = 'typescript', spec = require('neocraft.lang.typescript') },
  { name = 'python', spec = require('neocraft.lang.python') },
}

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

M.servers = merge_map('servers')
M.tools = merge_tools()
M.formatters_by_ft = merge_map('formatters_by_ft')

return M
