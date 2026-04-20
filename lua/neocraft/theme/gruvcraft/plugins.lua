-- Gruvcraft plugin highlight groups.

local M = {}

local set = require('neocraft.theme.util').set

-- Schedule setting some highlight group after plugins have loaded, to prevent overriding by the plugin own highlights.
---@param spec neocraft.theme.Spec
local function schedule_post_plugin_hl(spec)
  local virtcolumn_fg = spec.colors.lighter_background
  local theme_name = spec.name

  vim.schedule(function()
    if vim.g.colors_name ~= theme_name then return end
    set('VirtColumn', virtcolumn_fg)
  end)
end

-- Set up highlight groups for plugins, and schedule any highlights that need to be set after certain plugins loaded.
---@param spec neocraft.theme.Spec
function M.setup(spec)
  local c = spec.colors

  -- stylua: ignore start
  set('IblIndent',                    c.dark_gray)
  set('IblWhitespace',                c.dark_gray)
  set('MiniIndentscopeSymbol',        c.gray)

  set('MiniCursorword',               nil,            c.dark_gray,            { bold = true, underline = false })
  set('MiniCursorwordCurrent',        nil,            nil,                    { bold = true, underline = false })

  set('MiniJump2dSpot',               nil,            c.dark_gray)
  set('MiniJump2dSpotUnique',         nil,            c.dark_gray)

  set('MiniStatuslineModeNormal',     c.black,        c.blue,                 { bold = true })
  set('MiniStatuslineModeInsert',     c.black,        c.green,                { bold = true })
  set('MiniStatuslineModeVisual',     c.black,        c.yellow,               { bold = true })
  set('MiniStatuslineModeReplace',    c.black,        c.red,                  { bold = true })
  set('MiniStatuslineModeCommand',    c.black,        c.normal,               { bold = true })
  set('MiniStatuslineModeOther',      c.black,        c.gray,                 { bold = true })

  set('MiniTablineCurrent',           c.black,        c.normal,               { bold = true })
  set('MiniTablineVisible',           c.gray,         c.background)
  set('MiniTablineHidden',            c.gray,         c.background)
  set('MiniTablineModifiedCurrent',   c.purple,       c.normal,               { bold = true, italic = true })
  set('MiniTablineModifiedVisible',   c.purple,       c.background,           { italic = true })
  set('MiniTablineModifiedHidden',    c.purple,       c.background,           { italic = true })
  set('MiniTablineTabpagesection',    c.black,        c.gray,                 { bold = true })

  set('TreesitterContext',            nil,            c.dark_gray)
  set('TreesitterContextLineNumber',  c.normal,       c.dark_gray)

  set('MiniFilesCursorLine',          c.background,   c.blue)
  set('MiniFilesBorder',              c.blue,         c.background)
  set('MiniFilesTitleFocused',        c.white,        c.background,           { bold = true })

  set('MiniNotifyBorder',             c.blue,         c.background)
  set('MiniNotifyTitle',              c.blue,         c.background)

  set('MiniPickBorder',               c.blue)

  set('MiniMapNormal',                c.lighter_gray, c.lighter_background)
  set('MiniMapSymbolLine',            c.white,        c.lighter_background)
  set('MiniMapSymbolView',            c.blue,         c.lighter_background)

  set('MiniClueBorder',               c.blue)
  set('MiniClueDescSingle',           c.white,        nil,                    { bold = false })
  set('MiniClueDescGroup',            c.blue,         nil,                    { bold = true })

  set('MiniHipatternsFixme',          c.black,        c.red_hl,               { bold = true })
  set('MiniHipatternsHack',           c.black,        c.orange_hl,            { bold = true })
  set('MiniHipatternsTodo',           c.black,        c.yellow_hl,            { bold = true })
  set('MiniHipatternsNote',           c.black,        c.blue_hl,              { bold = true })
  set('MiniHipatternsOK',             c.black,        c.green_hl,             { bold = true })

  set('RenderMarkdownH1',             c.purple)
  set('RenderMarkdownH1Bg',           c.purple)
  set('markdownH1',                   c.purple)
  set('RenderMarkdownH2',             c.orange)
  set('RenderMarkdownH2Bg',           c.orange)
  set('markdownH2',                   c.orange)
  set('RenderMarkdownH3',             c.red)
  set('RenderMarkdownH3Bg',           c.red)
  set('markdownH3',                   c.red)
  set('RenderMarkdownH4',             c.yellow)
  set('RenderMarkdownH4Bg',           c.yellow)
  set('markdownH4',                   c.yellow)
  set('RenderMarkdownH5',             c.yellow)
  set('RenderMarkdownH5Bg',           c.yellow)
  set('markdownH5',                   c.yellow)
  set('RenderMarkdownH6',             c.yellow)
  set('RenderMarkdownH6Bg',           c.yellow)
  set('markdownH6',                   c.yellow)
  set('RenderMarkdownCodeInline',     c.green,        c.lighter_background)
  set('RenderMarkdownCode',           nil,            c.lighter_background)
  set('RenderMarkdownCodeBorder',     c.normal,       c.lighter_background)
  set('RenderMarkdownBullet',         c.brown)
  set('RenderMarkdownDash',           c.dark_gray)
  set('RenderMarkdownQuote',          c.dark_gray)
  set('@markup.quote',                c.gray)
  set('RenderMarkdownTableHead',      c.normal)
  set('RenderMarkdownTableRow',       c.gray)
  set('RenderMarkdownLink',           c.blue)
  -- stylua: ignore end

  schedule_post_plugin_hl(spec)
end

return M
