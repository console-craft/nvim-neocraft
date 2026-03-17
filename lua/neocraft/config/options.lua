local opt = vim.opt

-- stylua: ignore start
-- Global settings
vim.g.mapleader                  = ' '                              -- Use `<Space>` as <Leader> key
vim.g.maplocalleader             = '\\'                             -- Explicitly set `\` (default) as <LocalLeader> key
vim.g.markdown_recommended_style = 0                                -- Disable legacy markdown style defaults

-- General
opt.clipboard                    = vim.env.SSH_CONNECTION and '' or 'unnamedplus' -- Sync with system clipboard
opt.mouse                        = 'a'                              -- Enable mouse
opt.termguicolors                = true                             -- True color support
opt.confirm                      = true                             -- Confirm to save changes before exiting modified buffer
opt.undofile                     = true                             -- Enable persistent undo
opt.updatetime                   = 250                              -- Decrease update time
opt.timeoutlen                   = 300                              -- Decrease mapped sequence wait time

-- UI
opt.number                       = true                             -- Show line numbers
opt.relativenumber               = true                             -- Show relative line numbers
opt.showmode                     = false                            -- Don't show mode in command line
opt.ruler                        = false                            -- Don't show cursor position in command line
opt.signcolumn                   = 'yes'                            -- Always show signcolumn
opt.cursorline                   = true                             -- Enable current line highlighting
opt.cursorlineopt                = 'screenline,number'              -- Focus cursorline on the active screen line and number column
opt.scrolloff                    = 4                                -- Lines of context
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
opt.wrap                         = false                            -- Disable visual line wrapping by default
opt.linebreak                    = true                             -- Wrap at word boundaries when wrapping is enabled
opt.breakindent                  = true                             -- Indent wrapped lines to match line start
opt.breakindentopt               = 'list:-1'                        -- Add padding for wrapped list items
opt.colorcolumn                  = '120'                            -- Use a 120-column guide in code buffers by default
opt.pumheight                    = 10                               -- Keep completion popups compact
opt.pummaxwidth                  = 100                              -- Make popup menu not too wide
opt.pumborder                    = 'single'                         -- Add a border to popup menus
opt.winborder                    = 'single'                         -- Use a single border for floating windows

-- Windows
opt.splitright                   = true                             -- Open vertical splits to the right
opt.splitbelow                   = true                             -- Open horizontal splits below
opt.splitkeep                    = 'screen'                         -- Reduce scroll during window split

-- Search
opt.ignorecase                   = true                             -- Case-insensitive searching by default
opt.smartcase                    = true                             -- Case-sensitive searching triggered by \C or capital letters in the pattern
opt.incsearch                    = true                             -- Show search matches while typing
opt.grepprg                      = 'rg --vimgrep'                   -- Use ripgrep for builtin :grep
opt.grepformat                   = '%f:%l:%c:%m'                    -- Parse ripgrep output correctly
opt.wildmode                     = 'longest:full,full'              -- Improve command-line completion
opt.iskeyword:append('-')                                           -- Treat dash-separated words as a single word

-- Editing
opt.expandtab                    = true                             -- Use spaces instead of tabs
opt.shiftwidth                   = 2                                -- Size of an indent
opt.tabstop                      = 2                                -- Number of spaces tabs count for
opt.autoindent                   = true                             -- Copy the indentation from the previous line
opt.smartindent                  = true                             -- Use C style brace-based indentation
opt.shiftround                   = true                             -- Round indent shifts to the nearest step
opt.virtualedit                  = 'block'                          -- Allow blockwise selection past end of line

-- Completion
opt.infercase                    = true                             -- Infer case in built-in completion

-- Prose
opt.formatlistpat                = [[^\s*[0-9\-\+\*]\+[\.\)]*\s\+]] -- Recognize numbered and bulleted lists
opt.spelloptions                 = 'camel'                          -- Treat camelCase word parts as separate words
-- stylua: ignore end

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
