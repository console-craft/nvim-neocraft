local pack = require('neocraft.core.pack')

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Settings                                  │
-- └───────────────────────────────────────────┘

local parsers = {
  'angular',
  'astro',
  'bash',
  'css',
  'diff',
  'dockerfile',
  'editorconfig',
  'gitattributes',
  'gitcommit',
  'git_config',
  'git_rebase',
  'gitignore',
  'go',
  'gomod',
  'gosum',
  'graphql',
  'html',
  'javascript',
  'jsdoc',
  'json',
  'lua',
  'luadoc',
  'luap',
  'markdown',
  'markdown_inline',
  'mermaid',
  'prisma',
  'python',
  'requirements',
  'scss',
  'sql',
  'svelte',
  'toml',
  'tsx',
  'typescript',
  'vim',
  'vimdoc',
  'vue',
  'yaml',
}

local foldexpr = 'v:lua.vim.treesitter.foldexpr()'
local indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

-- ┌───────────────────────────────────────────┐
-- │ Install and keep parsers updated          │
-- └───────────────────────────────────────────┘

pack.add('treesitter', {
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main' },
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter-textobjects', version = 'main' },
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter-context' },
  { src = 'https://github.com/windwp/nvim-ts-autotag' },
})

pack.on_changed('nvim-treesitter', 'update', function() vim.cmd('TSUpdate') end, 'Update tree-sitter parsers')

-- ┌───────────────────────────────────────────┐
-- │ Attach to supported buffers               │
-- │ Setup folds and indentation               │
-- └───────────────────────────────────────────┘

Lib.now(function() require('nvim-treesitter').install(parsers) end)

local function apply_folds(buf)
  if vim.b[buf].neocraft_treesitter_folds == true then
    vim.wo.foldmethod = 'expr'
    vim.wo.foldexpr = foldexpr
    return
  end

  if vim.wo.foldmethod == 'expr' and vim.wo.foldexpr == foldexpr then
    vim.wo.foldmethod = 'indent'
    vim.wo.foldexpr = '0'
  end
end

local function apply_indents(buf)
  if vim.b[buf].neocraft_treesitter_indents == true then
    vim.bo[buf].indentexpr = indentexpr
    return
  end

  if vim.bo[buf].indentexpr == indentexpr then vim.bo[buf].indentexpr = '' end
end

local function has_query(lang, query)
  local ok, parsed = pcall(vim.treesitter.query.get, lang, query)
  return ok and parsed ~= nil
end

local function has_parser(lang)
  if type(lang) ~= 'string' or lang == '' then return false end

  local ok, parser = pcall(vim.treesitter.language.add, lang)
  return ok and parser ~= nil and parser ~= false
end

local function get_lang(buf)
  local filetype = vim.bo[buf].filetype
  return vim.treesitter.language.get_lang(filetype) or filetype
end

local function attach(buf)
  local lang = get_lang(buf)
  if not has_parser(lang) then
    vim.b[buf].neocraft_treesitter_lang = nil
    vim.b[buf].neocraft_treesitter_folds = false
    vim.b[buf].neocraft_treesitter_indents = false
    return
  end

  vim.b[buf].neocraft_treesitter_lang = lang
  vim.b[buf].neocraft_treesitter_folds = has_query(lang, 'folds')
  vim.b[buf].neocraft_treesitter_indents = has_query(lang, 'indents')

  vim.treesitter.start(buf, lang)
end

local group = Lib.augroup('treesitter')

Lib.autocmd('FileType', {
  group = group,
  desc = 'Attach Neocraft tree-sitter features for supported buffers',
  callback = function(args)
    attach(args.buf)
    apply_folds(args.buf)
    apply_indents(args.buf)
  end,
})

Lib.autocmd('BufWinEnter', {
  group = group,
  desc = 'Apply tree-sitter fold settings when showing a buffer',
  callback = function(args) apply_folds(args.buf) end,
})

-- ┌───────────────────────────────────────────┐
-- │ Treesitter Text Objects                   │
-- └───────────────────────────────────────────┘

Lib.now(function()
  require('nvim-treesitter-textobjects').setup({ move = { set_jumps = true } })

  local move = require('nvim-treesitter-textobjects.move')

  local map = function(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { silent = true, desc = desc }) end

  map(']f', function() move.goto_next_start('@function.outer') end, 'Next function start')
  map(']F', function() move.goto_next_end('@function.outer') end, 'Next function end')
  map('[f', function() move.goto_previous_start('@function.outer') end, 'Prev function start')
  map('[F', function() move.goto_previous_end('@function.outer') end, 'Prev function end')
  map(']c', function() move.goto_next_start('@class.outer') end, 'Next class start')
  map(']C', function() move.goto_next_end('@class.outer') end, 'Next class end')
  map('[c', function() move.goto_previous_start('@class.outer') end, 'Prev class start')
  map('[C', function() move.goto_previous_end('@class.outer') end, 'Prev class end')
  map(']z', function() move.goto_next_start('@fold', 'folds') end, 'Next fold')
  map('[z', function() move.goto_previous_start('@fold', 'folds') end, 'Prev fold')
end)

-- ┌───────────────────────────────────────────┐
-- │ Treesitter Context                        │
-- └───────────────────────────────────────────┘

Lib.later(function()
  local ok, context = pcall(require, 'treesitter-context')
  if not ok then return end

  context.setup({
    trim_scope = 'inner',
    mode = 'topline',
    max_lines = 2,
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ nvim-ts-autotag                           │
-- └───────────────────────────────────────────┘

Lib.later(function()
  local ok, autotag = pcall(require, 'nvim-ts-autotag')
  if ok then autotag.setup({}) end
end)

return M
