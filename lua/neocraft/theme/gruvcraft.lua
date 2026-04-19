local runtime = require('neocraft.theme.runtime')
local util = require('neocraft.theme.util')

local M = {}
local state = { current = nil }

local link = util.link
local set = util.set

local variants = {
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
}

local function base16_palette(colors)
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

local function with_base16(spec)
  local resolved = vim.deepcopy(spec)
  resolved.base16 = base16_palette(resolved.colors)
  return resolved
end

local function schedule_post_plugin_hl(spec)
  local virtcolumn_fg = spec.colors.lighter_background
  local theme_name = spec.name

  vim.schedule(function()
    if vim.g.colors_name ~= theme_name then return end
    set('VirtColumn', virtcolumn_fg)
  end)
end

local function setup_builtin_syntax_hl(spec)
  local c = spec.colors

  -- stylua: ignore start
  set('Comment',           c.lighter_gray)
  set('Identifier',        c.yellow)
  set('Structure',         c.yellow)
  set('Macro',             c.yellow)
  set('Function',          c.blue,  nil,     { bold = true })
  set('Special',           c.aqua)
  set('String',            c.green)
  set('Character',         c.red)
  set('Number',            c.red)
  set('Boolean',           c.red)
  set('Type',              c.white)
  set('SpecialChar',       c.normal)
  set('Statement',         c.normal)
  set('Debug',             c.purple)
  set('PreProc',           c.purple, nil,    { bold = true })
  set('Tag',               c.normal, nil,    { bold = true })
  set('Delimiter',         c.brown)
  set('MatchParen',        c.yellow, c.gray, { underline = false })

  link('SpecialComment', 'Comment')
  link('Constant',       'Identifier')
  link('Float',          'Number')
  -- stylua: ignore end

  local statement_hl = 'Statement'
  vim
    .iter({ 'Keyword', 'Conditional', 'Repeat', 'Label', 'Operator', 'Exception', 'Typedef', 'TypeDef', 'StorageClass' })
    :each(function(item) link(item, statement_hl) end)

  local preproc_hl = 'PreProc'
  vim.iter({ 'Include', 'Define', 'PreCondit' }):each(function(item) link(item, preproc_hl) end)
end

local function setup_treesitter_syntax_hl(spec)
  local c = spec.colors

  -- stylua: ignore start
  set('@constant.builtin',              c.red)
  set('@variable.parameter.builtin',    c.normal)
  set('@type.builtin',                  c.normal)
  set('@property',                      c.normal)
  set('@constructor',                   c.yellow)
  set('@module.builtin',                c.normal)
  set('@variable.member',               c.normal)
  set('@keyword.coroutine',             c.purple)
  set('@keyword.return',                c.purple, nil, { bold = true })
  set('@punctuation.bracket',           c.yellow)
  set('@tag',                           c.brown, nil,  { bold = true })

  link('@constant',                    'Constant')
  link('@constant.macro',              'Macro')
  link('@string',                      'String')
  link('@character',                   'Character')
  link('@string.documentation',        'SpecialComment')
  link('@number',                      'Number')
  link('@number.float',                'Float')
  link('@boolean',                     'Boolean')
  link('@type',                        'Type')
  link('@type.definition',             'TypeDef')
  link('@module',                      'Structure')
  link('@operator',                    'Operator')
  link('@label',                       'Label')
  link('@keyword.conditional',         'Conditional')
  link('@keyword.conditional.ternary', 'Conditional')
  link('@keyword.repeat',              'Repeat')
  link('@keyword.exception',           'Exception')
  link('@keyword.debug',               'Debug')
  link('@keyword.import',              'Include')
  link('@keyword.directive.define',    'Define')
  link('@punctuation.delimiter',       'Delimiter')
  link('@tag.builtin',                 'Tag')
  link('@tag.attribute',               'Tag')
  link('@tag.delimiter',               'Delimiter')
  -- stylua: ignore end

  local comment_hl = 'Comment'
  vim
    .iter({
      '@comment',
      '@comment.documentation',
      '@keyword.directive',
      '@keyword.jsdoc',
      '@keyword.luadoc',
      '@keyword.return.luadoc',
    })
    :each(function(item) link(item, comment_hl) end)

  local identifier_hl = 'Identifier'
  vim
    .iter({
      '@variable',
      '@variable.builtin',
      '@variable.parameter',
    })
    :each(function(item) link(item, identifier_hl) end)

  local specialchar_hl = 'SpecialChar'
  vim
    .iter({
      '@string.regexp',
      '@string.special',
      '@string.special.symbol',
      '@string.special.path',
      '@string.special.url',
      '@string.special.vimdoc',
      '@string.escape',
      '@character.special',
    })
    :each(function(item) link(item, specialchar_hl) end)

  local special_hl = 'Special'
  vim
    .iter({
      '@function.builtin',
      '@function.call',
      '@function.macro',
      '@function.method',
      '@function.method.call',
      '@punctuation.special',
    })
    :each(function(item) link(item, special_hl) end)

  local function_hl = 'Function'
  vim
    .iter({
      '@function',
      '@attribute',
      '@attribute.builtin',
    })
    :each(function(item) link(item, function_hl) end)

  local keyword_hl = 'Keyword'
  vim
    .iter({
      '@keyword',
      '@keyword.operator',
      '@keyword.function',
      '@keyword.type',
      '@keyword.modifier',
    })
    :each(function(item) link(item, keyword_hl) end)
end

local function setup_semantic_token_syntax_hl()
  for _, hl in ipairs(vim.fn.getcompletion('@lsp', 'highlight')) do
    vim.api.nvim_set_hl(0, hl, {})
  end

  -- stylua: ignore start
  link('@lsp.type.parameter',     '@variable.parameter')
  link('@lsp.type.property',      '@property')
  link('@lsp.type.variable',      '@variable')
  link('@lsp.type.typeParameter', '@type')
  link('@lsp.type.namespace',     '@module')
  link('@lsp.type.enumMember',    '@variable.member')
  -- stylua: ignore end

  set('@lsp.mod.deprecated', nil, nil, { strikethrough = true })
end

local function setup_editor_hl(spec)
  local c = spec.colors

  -- Base editor surfaces.
  -- stylua: ignore start
  set('Normal',                    nil,                  c.background)
  set('NormalNC',                  nil,                  c.darker_background)
  set('ColorColumn',               nil,                  c.lighter_background)
  set('VirtColumn',                c.lighter_background)
  set('CursorLine',                nil,                  c.lighter_background)
  set('CursorLineNr',              c.normal,             c.lighter_background)
  set('WinSeparator',              c.lighter_background, c.darker_background)
  set('FloatBorder',               c.blue,               c.background)
  set('PmenuBorder',               c.blue,               c.background)
  set('WinBar',                    c.black,              c.blue,                { bold = true })
  set('WinBarNC',                  c.white,              c.lighter_background)
  set('MsgArea',                   c.white,              nil,                   { bold = true })
  set('Folded',                    nil,                  'NONE')
  set('ComplHintMore',             c.yellow)
  -- stylua: ignore end

  -- Search.
  -- stylua: ignore start
  set('Search',                    nil,         c.yellow)
  set('IncSearch',                 nil,         c.orange)
  link('CurSearch',                'IncSearch')
  -- stylua: ignore end

  -- Text selection.
  -- stylua: ignore start
  link('Visual',                   'Search')
  link('VisualNOS',                'Search')
  -- stylua: ignore end

  -- Completion, inlay hints, and codelens.
  set('ComplHint', c.gray, nil, { italic = true })
  vim
    .iter({ 'LspCodelens', 'LspCodelensSeparator', 'LspInlayHint' })
    :each(function(hl) set(hl, c.dark_gray, nil, { italic = true }) end)

  -- LSP references highlights.
  vim
    .iter({
      'LspReferenceText',
      'LspReferenceRead',
      'LspReferenceWrite',
      'LspReferenceTarget',
      'LspSignatureActiveParameter',
    })
    :each(function(hl) set(hl, nil, c.dark_gray) end)

  -- Diagnostics.
  -- stylua: ignore start
  set('DiagnosticVirtualTextWarn',  c.orange_hl)
  set('DiagnosticVirtualTextError', c.red_hl)
  set('DiagnosticVirtualTextInfo',  c.aqua_hl)
  set('DiagnosticVirtualTextHint',  c.blue_hl)
  set('DiagnosticVirtualTextOK',    c.green_hl)
  -- stylua: ignore end

  link('SpellBad', 'SpellLocal')

  for kind, sp in pairs({
    Warn = c.orange_hl,
    Error = c.red_hl,
    Info = c.aqua_hl,
    Hint = c.blue_hl,
    OK = c.green_hl,
  }) do
    set('DiagnosticUnderline' .. kind, nil, nil, { undercurl = true, sp = sp })
  end

  vim.iter({ 'NotifyWARNBorder', 'DiagnosticWarn', 'DiagnosticFloatingWarn' }):each(function(hl) set(hl, c.orange) end)
end

local function setup_diff_hl(spec)
  local c = spec.colors

  -- stylua: ignore start
  set('DiffAdd',                'NONE',         c.diff_light)
  set('DiffChange',             c.gray,         c.lighter_background)
  set('DiffText',               'NONE',         c.diff_light)
  set('DiffDelete',             c.gray,         c.diff_dark)

  set('MiniDiffSignAdd',        c.green,        c.diff_dark)
  set('MiniDiffSignChange',     c.diff_changed, c.diff_dark)
  set('MiniDiffSignDelete',     c.red,          c.diff_dark)
  set('MiniDiffOverChange',     c.gray,         c.diff_prev_changed)
  set('MiniDiffOverChangeBuf',  'NONE',         c.diff_changed)
  set('MiniDiffOverContext',    c.gray,         c.diff_dark)
  set('MiniDiffOverContextBuf', 'NONE',         c.diff_light)

  set('CopilotLspNesAdd',       c.black,        c.green)
  set('CopilotLspNesDelete',    c.black,        c.red)

  set('NeocraftMiniDiffCount',  c.diff_changed)
  -- stylua: ignore end
end

local function setup_markdown_hl(spec)
  local c = spec.colors

  -- stylua: ignore start
  set('RenderMarkdownH1',         c.purple)
  set('RenderMarkdownH1Bg',       c.purple)
  set('markdownH1',               c.purple)
  set('RenderMarkdownH2',         c.orange)
  set('RenderMarkdownH2Bg',       c.orange)
  set('markdownH2',               c.orange)
  set('RenderMarkdownH3',         c.red)
  set('RenderMarkdownH3Bg',       c.red)
  set('markdownH3',               c.red)
  set('RenderMarkdownH4',         c.yellow)
  set('RenderMarkdownH4Bg',       c.yellow)
  set('markdownH4',               c.yellow)
  set('RenderMarkdownH5',         c.yellow)
  set('RenderMarkdownH5Bg',       c.yellow)
  set('markdownH5',               c.yellow)
  set('RenderMarkdownH6',         c.yellow)
  set('RenderMarkdownH6Bg',       c.yellow)
  set('markdownH6',               c.yellow)
  set('RenderMarkdownCodeInline', c.green,      c.lighter_background)
  set('RenderMarkdownCode',       nil,          c.lighter_background)
  set('RenderMarkdownCodeBorder', c.normal,     c.lighter_background)
  set('RenderMarkdownBullet',     c.brown)
  set('RenderMarkdownDash',       c.dark_gray)
  set('RenderMarkdownQuote',      c.dark_gray)
  set('@markup.quote',            c.gray)
  set('RenderMarkdownTableHead',  c.normal)
  set('RenderMarkdownTableRow',   c.gray)
  set('RenderMarkdownLink',       c.blue)
  -- stylua: ignore end
end

local function setup_plugin_hl(spec)
  local c = spec.colors

  -- stylua: ignore start
  set('IblIndent',                  c.dark_gray)
  set('IblWhitespace',              c.dark_gray)
  set('MiniIndentscopeSymbol',      c.gray)

  set('MiniCursorword',             nil,      c.dark_gray,            { bold = true, underline = false, undercurl = false, underdotted = false, underdashed = false })
  set('MiniCursorwordCurrent',      nil,      nil,                    { bold = true, underline = false, undercurl = false, underdotted = false, underdashed = false })

  set('MiniJump2dSpot',             nil,  c.dark_gray)
  set('MiniJump2dSpotUnique',       nil,  c.dark_gray)

  set('MiniStatuslineModeNormal',   c.black,  c.blue,                 { bold = true })
  set('MiniStatuslineModeInsert',   c.black,  c.green,                { bold = true })
  set('MiniStatuslineModeVisual',   c.black,  c.yellow,               { bold = true })
  set('MiniStatuslineModeReplace',  c.black,  c.red,                  { bold = true })
  set('MiniStatuslineModeCommand',  c.black,  c.orange,               { bold = true })
  set('MiniStatuslineModeOther',    c.black,  c.gray,                 { bold = true })

  set('MiniTablineCurrent',         c.black,  c.normal,               { bold = true })
  set('MiniTablineVisible',         c.gray,   c.background)
  set('MiniTablineHidden',          c.gray,   c.background)
  set('MiniTablineModifiedCurrent', c.purple, c.normal,               { bold = true, italic = true })
  set('MiniTablineModifiedVisible', c.purple, c.background,           { italic = true })
  set('MiniTablineModifiedHidden',  c.purple, c.background,           { italic = true })
  set('MiniTablineTabpagesection',  c.black,  c.purple,                 { bold = true })

  set('TreesitterContext',          nil,       c.dark_gray)
  set('TreesitterContextLineNumber',c.normal,  c.dark_gray)

  set('MiniFilesCursorLine',        c.background, c.blue)
  set('MiniFilesBorder',            c.blue,   c.background)
  set('MiniFilesTitleFocused',      c.white,  c.background,           { bold = true })

  set('MiniNotifyBorder',           c.blue,   c.background)
  set('MiniNotifyTitle',            c.blue,   c.background)

  set('MiniPickBorder',             c.blue)

  set('MiniMapNormal',              c.lighter_gray,  c.lighter_background)
  set('MiniMapSymbolLine',          c.white,  c.lighter_background)
  set('MiniMapSymbolView',          c.blue,   c.lighter_background)

  set('MiniClueBorder',             c.blue)
  set('MiniClueDescSingle',         c.white,  nil,                    { bold = false })
  set('MiniClueDescGroup',          c.blue,   nil,                    { bold = true })

  set('MiniHipatternsFixme',        c.black,  c.red_hl,               { bold = true })
  set('MiniHipatternsHack',         c.black,  c.orange_hl,            { bold = true })
  set('MiniHipatternsTodo',         c.black,  c.yellow_hl,            { bold = true })
  set('MiniHipatternsNote',         c.black,  c.blue_hl,              { bold = true })
  set('MiniHipatternsOK',           c.black,  c.green_hl,              { bold = true })
  -- stylua: ignore end
end

function M.spec(variant)
  local spec = variants[variant]
  assert(spec ~= nil, string.format("Unknown gruvcraft variant '%s'", tostring(variant)))
  return with_base16(spec)
end

function M.current()
  if state.current == nil then return nil end
  return vim.deepcopy(state.current)
end

function M.apply(variant)
  local spec = M.spec(variant)
  state.current = spec

  require('mini.base16').setup({
    palette = spec.base16,
    use_cterm = true,
    plugins = { default = true },
  })

  setup_builtin_syntax_hl(spec)
  setup_treesitter_syntax_hl(spec)
  setup_semantic_token_syntax_hl()
  setup_editor_hl(spec)
  setup_diff_hl(spec)
  setup_markdown_hl(spec)
  setup_plugin_hl(spec)
  schedule_post_plugin_hl(spec)
  runtime.setup(spec)
  vim.g.colors_name = spec.name
end

return M
