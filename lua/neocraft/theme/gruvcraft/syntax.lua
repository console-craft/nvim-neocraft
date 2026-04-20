-- Gruvcraft syntax highlights.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local util = require('neocraft.theme.util')
local link = util.link
local set = util.set

-- Set up the syntax highlight groups for built-in syntax elements.
---@param spec neocraft.theme.Spec
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

  link('SpecialComment',  'Comment')
  link('Constant',        'Identifier')
  link('Float',           'Number')
  -- stylua: ignore end

  local statement_hl = 'Statement'
  vim
    .iter({ 'Keyword', 'Conditional', 'Repeat', 'Label', 'Operator', 'Exception', 'Typedef', 'TypeDef', 'StorageClass' })
    :each(function(item) link(item, statement_hl) end)

  local preproc_hl = 'PreProc'
  vim.iter({ 'Include', 'Define', 'PreCondit' }):each(function(item) link(item, preproc_hl) end)
end

-- Set up the syntax highlight groups for Tree-sitter syntax elements.
---@param spec neocraft.theme.Spec
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

-- Set up the syntax highlight groups for LSP semantic tokens.
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

-- ┌───────────────────────────────────────────┐
-- │ Setup syntax highlighting                 │
-- └───────────────────────────────────────────┘

-- Set up the syntax highlight groups for a theme variant.
---@param spec neocraft.theme.Spec
function M.setup(spec)
  setup_builtin_syntax_hl(spec)
  setup_treesitter_syntax_hl(spec)
  setup_semantic_token_syntax_hl()
end

return M
