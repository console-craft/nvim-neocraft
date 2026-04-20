-- Gruvcraft editor highlight groups.

local M = {}

local util = require('neocraft.theme.util')
local link = util.link
local set = util.set

-- Set up the editor built-in and diff related highlight groups.
---@param spec neocraft.theme.Spec
function M.setup(spec)
  local c = spec.colors

  -- Base editor surfaces

  -- stylua: ignore start
  set('Normal',                    nil,                   c.background)
  set('NormalNC',                  nil,                   c.darker_background)
  set('ColorColumn',               nil,                   c.lighter_background)
  set('VirtColumn',                c.lighter_background)
  set('CursorLine',                nil,                   c.lighter_background)
  set('CursorLineNr',              c.normal,              c.lighter_background)
  set('WinSeparator',              c.lighter_background,  c.darker_background)
  set('FloatBorder',               c.blue,                c.background)
  set('PmenuBorder',               c.blue,                c.background)
  set('WinBar',                    c.black,               c.blue,                { bold = true })
  set('WinBarNC',                  c.white,               c.lighter_background)
  set('MsgArea',                   c.white,               nil,                   { bold = true })
  set('Folded',                    nil,                   'NONE')
  set('ComplHintMore',             c.yellow)
  -- stylua: ignore end

  -- Search

  -- stylua: ignore start
  set('Search',                    nil,                   c.yellow)
  set('IncSearch',                 nil,                   c.orange)
  link('CurSearch',                'IncSearch')
  -- stylua: ignore end

  -- Text selection

  -- stylua: ignore start
  link('Visual',                   'Search')
  link('VisualNOS',                'Search')
  -- stylua: ignore end

  -- Completion, inlay hints, and codelens

  set('ComplHint', c.gray, nil, { italic = true })
  vim
    .iter({ 'LspCodelens', 'LspCodelensSeparator', 'LspInlayHint' })
    :each(function(hl) set(hl, c.dark_gray, nil, { italic = true }) end)

  -- LSP references highlights

  vim
    .iter({
      'LspReferenceText',
      'LspReferenceRead',
      'LspReferenceWrite',
      'LspReferenceTarget',
      'LspSignatureActiveParameter',
    })
    :each(function(hl) set(hl, nil, c.dark_gray) end)

  -- Diagnostics

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

  -- Diffs

  -- stylua: ignore start
  set('DiffAdd',                    'NONE',         c.diff_light)
  set('DiffChange',                 c.gray,         c.lighter_background)
  set('DiffText',                   'NONE',         c.diff_light)
  set('DiffDelete',                 c.gray,         c.diff_dark)

  set('MiniDiffSignAdd',            c.green,        c.diff_dark)
  set('MiniDiffSignChange',         c.diff_changed, c.diff_dark)
  set('MiniDiffSignDelete',         c.red,          c.diff_dark)
  set('MiniDiffOverChange',         c.gray,         c.diff_prev_changed)
  set('MiniDiffOverChangeBuf',      'NONE',         c.diff_changed)
  set('MiniDiffOverContext',        c.gray,         c.diff_dark)
  set('MiniDiffOverContextBuf',     'NONE',         c.diff_light)

  set('NeocraftMiniDiffCount',      c.diff_changed)

  set('DiffviewFilePanelRootPath',  c.blue,         'NONE')
  set('DiffviewFilePanelTitle',     c.lighter_gray, 'NONE')
  set('DiffviewFilePanelFileName',  c.normal,       'NONE')
  set('DiffviewFilePanelCounter',   c.gray,         'NONE')
  set('DiffviewFolderSign',         c.blue,         'NONE')
  set('DiffviewStatusUntracked',    c.lighter_gray, 'NONE')
  set('DiffviewStatusModified',     c.green_hl,     'NONE')
  set('DiffviewDiffAdd',            'NONE',         c.diff_light)
  set('DiffviewDiffText',           'NONE',         c.diff_light)
  set('DiffviewDiffChange',         'NONE',         c.diff_dark)
  set('DiffviewDiffDelete',         'NONE',         c.diff_dark)
  set('DiffviewDiffDeleteDim',      c.diff_light,   'NONE')
  set('DiffviewFilePanelSelected',  c.black,        c.yellow)

  -- set('gitHashAbbrev',              c.black,        c.yellow,             { bold = true })
  -- set('gitHead',                    c.gray,         'NONE')
  -- set('gitKeyword',                 c.gray,         'NONE')
  -- set('gitDateHeader',              c.gray,         'NONE')
  -- set('gitIdentityHeader',          c.gray,         'NONE')
  -- set('gitDate',                    c.lighter_gray, 'NONE')
  -- set('gitIdentity',                c.lighter_gray, 'NONE')
  -- set('gitEmail',                   c.lighter_gray, 'NONE')
  -- set('DiffFile',                   c.white,        'NONE',             { bold = true })
  -- set('DiffOldFile',                c.gray,         'NONE')
  -- set('DiffNewFile',                c.gray,         'NONE')
  -- set('diffIndexLine',              c.gray,         'NONE')
  -- set('DiffLine',                   c.black,        c.dark_gray,               { bold = true })
  -- set('DiffSubName',                c.black,        c.dark_gray,               { bold = true })
  -- set('DiffAdded',                  'NONE',         c.diff_light)
  -- set('DiffRemoved',                c.gray,         c.diff_dark)
  --
  -- set('@string.special.path.diff',  c.black,        c.gray,             { bold = true })
  -- set('@function.diff',             c.gray,       'NONE')
  -- set('@variable.parameter.diff',   c.gray,       'NONE')
  -- set('@keyword.diff',              c.gray,         'NONE')
  -- set('@label.diff',                c.gray,         'NONE')
  -- set('@constant.diff',             c.black,       c.yellow)
  -- set('@number.diff',               c.gray,         'NONE')
  -- set('@punctuation.special.diff',  c.black,       c.yellow)
  -- set('@attribute.diff',            c.black,        c.dark_gray,               { bold = true })
  -- set('@diff.plus.diff',            'NONE',         c.diff_light)
  -- set('@diff.minus.diff',           c.gray,         c.diff_dark)

  -- stylua: ignore end
end

return M
