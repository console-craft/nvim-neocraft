-- Configure mini.pick and expose Neocraft picker helpers.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local pickers = require('neocraft.features.pickers')

local public_custom_pickers = {
  actions = pickers.actions,
  all_files = pickers.all_files,
  all_grep_cword = pickers.all_grep_cword,
  all_grep_live = pickers.all_grep_live,
  all_todos = pickers.all_todos,
  autocmds = pickers.autocmds,
  grep_cword = pickers.grep_cword,
  location_list = pickers.location_list,
  quickfix_list = pickers.quickfix_list,
  todos = pickers.todos,
}

-- Calculate window configuration for pickers based on current editor dimensions, with limits on size and position.
local win_config = function()
  local lines = vim.o.lines
  local columns = vim.o.columns
  local height = math.min(math.max(math.floor(lines * 0.75), 25), 50)
  local width = math.min(math.max(math.floor(columns * 0.90), 80), 180)
  height = math.min(height, lines - 2)
  width = math.min(width, columns - 4)
  return {
    anchor = 'NW',
    height = height,
    width = width,
    row = math.floor((lines - height) * 0.5),
    col = math.floor((columns - width) * 0.5),
  }
end

-- ┌───────────────────────────────────────────┐
-- │ Setup Mini Pick & register custom pickers │
-- └───────────────────────────────────────────┘

Lib.later(function()
  local mini_pick = require('mini.pick')

  mini_pick.setup({ window = { config = win_config } })

  for name, picker in pairs(public_custom_pickers) do
    mini_pick.registry[name] = picker
  end
end)

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

M.public_custom_pickers = public_custom_pickers

return M
