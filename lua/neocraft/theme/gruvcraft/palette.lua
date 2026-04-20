-- Gruvcraft palette definitions and Base16 conversion helpers.

---@alias neocraft.theme.ColorValue string|integer

---@class neocraft.theme.Colors
---@field white neocraft.theme.ColorValue
---@field lighter neocraft.theme.ColorValue
---@field normal neocraft.theme.ColorValue
---@field purple neocraft.theme.ColorValue
---@field blue neocraft.theme.ColorValue
---@field orange neocraft.theme.ColorValue
---@field aqua neocraft.theme.ColorValue
---@field green neocraft.theme.ColorValue
---@field red neocraft.theme.ColorValue
---@field yellow neocraft.theme.ColorValue
---@field brown neocraft.theme.ColorValue
---@field purple_hl neocraft.theme.ColorValue
---@field blue_hl neocraft.theme.ColorValue
---@field orange_hl neocraft.theme.ColorValue
---@field aqua_hl neocraft.theme.ColorValue
---@field green_hl neocraft.theme.ColorValue
---@field red_hl neocraft.theme.ColorValue
---@field yellow_hl neocraft.theme.ColorValue
---@field brown_hl neocraft.theme.ColorValue
---@field lighter_gray neocraft.theme.ColorValue
---@field gray neocraft.theme.ColorValue
---@field dark_gray neocraft.theme.ColorValue
---@field lighter_background neocraft.theme.ColorValue
---@field background neocraft.theme.ColorValue
---@field darker_background neocraft.theme.ColorValue
---@field black neocraft.theme.ColorValue
---@field diff_light neocraft.theme.ColorValue
---@field diff_changed neocraft.theme.ColorValue
---@field diff_prev_changed neocraft.theme.ColorValue
---@field diff_dark neocraft.theme.ColorValue

---@class neocraft.theme.Spec
---@field name string
---@field colors neocraft.theme.Colors

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Variants                                  │
-- └───────────────────────────────────────────┘

---@type table<string, neocraft.theme.Spec>
M.variants = {
  dark = {
    name = 'gruvcraft-dark',
    colors = {
      white = '#e6d5ae',
      lighter = '#ddc7a1',
      normal = '#d4be98',
      purple = '#d4a599',
      blue = '#adb79d',
      orange = '#eead83',
      aqua = '#b2ba8e',
      green = '#bac584',
      red = '#de9880',
      yellow = '#d6b37b',
      brown = '#ca9a70',
      purple_hl = '#d3869b',
      blue_hl = '#7daea3',
      orange_hl = '#e78a4e',
      aqua_hl = '#89b482',
      green_hl = '#a9b665',
      red_hl = '#ea6962',
      yellow_hl = '#d8a657',
      brown_hl = '#bd6f3e',
      lighter_gray = '#8b7d71',
      gray = '#695e55',
      dark_gray = '#4c4641',
      lighter_background = '#3b3634',
      background = '#33302e',
      darker_background = '#302e2c',
      black = '#2a2928',
      diff_light = '#51592a',
      diff_changed = '#829044',
      diff_prev_changed = '#414526',
      diff_dark = '#373a20',
    },
  },
  -- TODO: Add light variant.
}

-- ┌───────────────────────────────────────────┐
-- │ Palette helpers                           │
-- └───────────────────────────────────────────┘

-- Convert a color palette to the Base16 format expected by mini.base16, mapping the appropriate colors.
---@param colors neocraft.theme.Colors
---@return table<string, neocraft.theme.ColorValue>
function M.base16_palette(colors)
  return {
    base00 = colors.black,
    base01 = colors.background,
    base02 = colors.lighter_background,
    base03 = colors.dark_gray,
    base04 = colors.gray,
    base05 = colors.normal,
    base06 = colors.lighter,
    base07 = colors.white,
    base08 = colors.red,
    base09 = colors.orange,
    base0A = colors.yellow,
    base0B = colors.green,
    base0C = colors.aqua,
    base0D = colors.blue,
    base0E = colors.purple,
    base0F = colors.brown,
  }
end

return M
