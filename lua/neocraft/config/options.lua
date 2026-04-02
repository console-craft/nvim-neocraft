local opt = vim.opt

vim.env.RIPGREP_CONFIG_PATH = vim.fs.joinpath(vim.fn.stdpath('config'), '.ripgreprc')

-- stylua: ignore start

-- ┌───────────────────────────────────────────┐
-- │ Global Settings                           │
-- └───────────────────────────────────────────┘

vim.g.mapleader                  = ' '                              -- Use `<Space>` as <Leader> key
vim.g.markdown_recommended_style = 0                                -- Disable legacy markdown style defaults
vim.g.have_nerd_font             = true                             -- Enable icons in the UI

-- ┌───────────────────────────────────────────┐
-- │ General Settings                          │
-- └───────────────────────────────────────────┘

opt.clipboard                    = vim.env.SSH_CONNECTION and '' or 'unnamedplus' -- Sync with system clipboard
opt.mouse                        = 'a'                              -- Enable mouse
opt.termguicolors                = true                             -- True color support
opt.confirm                      = true                             -- Confirm to save changes before exiting modified buffer
opt.sessionoptions               = { 'buffers', 'help', 'localoptions', 'skiprtp', 'tabpages', 'winsize' }
opt.undofile                     = true                             -- Enable persistent undo
opt.updatetime                   = 250                              -- Decrease update time
opt.timeoutlen                   = 500                              -- Decrease mapped sequence wait time

-- ┌───────────────────────────────────────────┐
-- │ UI                                        │
-- └───────────────────────────────────────────┘

opt.number                       = true                             -- Show line numbers
opt.laststatus                   = 3                                -- Show a global statusline.
opt.winbar                       = "%f"                             -- Show file path in the window bar.
opt.shortmess:append({ W = true, I = true, c = true, C = true })    -- Suppress unnecessary messages for a cleaner UI.
opt.relativenumber               = false                            -- Don't show relative line numbers by default
opt.showmode                     = false                            -- Don't show mode in command line
opt.ruler                        = false                            -- Don't show cursor position in command line
opt.signcolumn                   = 'yes'                            -- Always show signcolumn
opt.cursorline                   = true                             -- Enable current line highlighting
opt.cursorlineopt                = 'screenline,number'              -- Focus cursorline on the active screen line and number column
opt.scrolloff                    = 2                                -- Lines of context
opt.sidescrolloff                = 8                                -- Columns of context for long lines
opt.list                         = true                             -- Show helpful text indicators
opt.listchars                    = {                                -- Whitespace characters display
  tab = '» ',
  trail = '·',
  nbsp = '␣',
}
opt.fillchars                    = {                                -- UI filler characters
  eob = ' ',
}
opt.foldenable                   = true                             -- Keep folding available without starting collapsed
opt.foldcolumn                   = '0'                              -- Don't reserve a dedicated fold column
opt.foldlevel                    = 99                               -- Keep folds open until explicitly closed
opt.foldlevelstart               = 99                               -- Start windows with folds open
opt.foldtext                     = ''                               -- Render folds with highlighted chunks and a count
opt.wrap                         = false                            -- Disable visual line wrapping by default
opt.linebreak                    = true                             -- Wrap at word boundaries when wrapping is enabled
opt.breakindent                  = true                             -- Indent wrapped lines to match line start
opt.breakindentopt               = 'list:-1'                        -- Add padding for wrapped list items
opt.colorcolumn                  = '120'                            -- Use a 120-column guide in code buffers by default
opt.pumheight                    = 10                               -- Keep completion popups compact
opt.pummaxwidth                  = 100                              -- Make popup menu not too wide
opt.pumborder                    = 'single'                         -- Add a border to popup menus
opt.winborder                    = 'single'                         -- Use a single border for floating windows
opt.pumblend                     = 10                               -- Make builtin completion menus slightly transparent
opt.winblend                     = 10                               -- Make floating windows slightly transparent

-- ┌───────────────────────────────────────────┐
-- │ Windows                                   │
-- └───────────────────────────────────────────┘

opt.splitright                   = true                             -- Open vertical splits to the right
opt.splitbelow                   = true                             -- Open horizontal splits below
opt.splitkeep                    = 'screen'                         -- Reduce scroll during window split

-- ┌───────────────────────────────────────────┐
-- │ Search                                    │
-- └───────────────────────────────────────────┘

opt.ignorecase                   = true                             -- Case-insensitive searching by default
opt.smartcase                    = true                             -- Case-sensitive searching triggered by \C or capital letters in the pattern
opt.incsearch                    = true                             -- Show search matches while typing
opt.grepprg                      = 'rg --vimgrep'                   -- Use ripgrep for builtin :grep
opt.grepformat                   = '%f:%l:%c:%m'                    -- Parse ripgrep output correctly
opt.wildmode                     = 'longest:full,full'              -- Improve command-line completion
opt.iskeyword:append('-')                                           -- Treat dash-separated words as a single word

-- ┌───────────────────────────────────────────┐
-- │ Editing                                   │
-- └───────────────────────────────────────────┘

opt.expandtab                    = true                             -- Use spaces instead of tabs
opt.shiftwidth                   = 2                                -- Size of an indent
opt.tabstop                      = 2                                -- Number of spaces tabs count for
opt.autoindent                   = true                             -- Copy the indentation from the previous line
opt.smartindent                  = true                             -- Use C style brace-based indentation
opt.shiftround                   = true                             -- Round indent shifts to the nearest step
opt.virtualedit                  = 'block'                          -- Allow blockwise selection past end of line

-- ┌───────────────────────────────────────────┐
-- │ Completions                               │
-- └───────────────────────────────────────────┘

opt.infercase                    = true                             -- Infer case in built-in completion

-- ┌───────────────────────────────────────────┐
-- │ Prose                                     │
-- └───────────────────────────────────────────┘

opt.spell                        = true                             -- Enable spelling by default
opt.spelloptions                 = 'camel'                          -- Treat camelCase word parts as separate words
opt.conceallevel                 = 3                                -- Hide bold/italic markers in Markdown.
opt.concealcursor                = "n"                              -- Conceal text in cursorline in normal mode.
opt.formatlistpat                = [[^\s*[0-9\-\+\*]\+[\.\)]*\s\+]] -- Recognize numbered and bulleted lists

-- stylua: ignore end

-- ┌───────────────────────────────────────────┐
-- │ Diagnostics                               │
-- └───────────────────────────────────────────┘

Lib.later(
  function()
    vim.diagnostic.config({
      severity_sort = true,
      update_in_insert = false,
      underline = true,
      virtual_text = {
        prefix = '',
        spacing = 4,
        source = 'if_many',
      },
      float = {
        border = 'rounded',
        source = true,
      },
      signs = {
        priority = 9999,
        text = {
          [vim.diagnostic.severity.ERROR] = ' ',
          [vim.diagnostic.severity.WARN] = ' ',
          [vim.diagnostic.severity.INFO] = ' ',
          [vim.diagnostic.severity.HINT] = ' ',
        },
      },
    })
  end
)
