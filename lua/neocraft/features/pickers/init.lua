local M = {}

local modules = {
  require('neocraft.features.pickers.core'),
  require('neocraft.features.pickers.extra'),
  require('neocraft.features.pickers.actions'),
  require('neocraft.features.pickers.git'),
}

for _, module in ipairs(modules) do
  for name, value in pairs(module) do
    M[name] = value
  end
end

return M
