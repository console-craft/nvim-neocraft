-- UI related plugins.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local pack = require('neocraft.core.pack')

local prose_filetypes = {
  'gitcommit',
  'markdown',
  'text',
}

local excluded_buftypes = {
  'terminal',
  'nofile',
  'quickfix',
  'prompt',
}

local excluded_ui_filetypes = {
  'checkhealth',
  'help',
  'lspinfo',
  'man',
  'neocraft-pack',
}

-- ┌───────────────────────────────────────────┐
-- │ Install plugins                           │
-- └───────────────────────────────────────────┘

pack.add('ui', {
  { src = 'https://github.com/NMAC427/guess-indent.nvim' },
  { src = 'https://github.com/lukas-reineke/indent-blankline.nvim' },
  { src = 'https://github.com/lukas-reineke/virt-column.nvim' },
  { src = 'https://github.com/MeanderingProgrammer/render-markdown.nvim' },
})

-- ┌───────────────────────────────────────────┐
-- │ Setup guess-indent                        │
-- └───────────────────────────────────────────┘

Lib.later(function()
  require('guess-indent').setup({
    override_editorconfig = false,
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ Setup indent-blankline                    │
-- └───────────────────────────────────────────┘

local ibl_excluded_filetypes = vim.list_extend(vim.deepcopy(prose_filetypes), vim.deepcopy(excluded_ui_filetypes))

Lib.later(
  function()
    require('ibl').setup({
      indent = {
        char = '┊',
      },
      scope = {
        enabled = false,
        show_start = false,
        show_end = false,
      },
      exclude = {
        buftypes = excluded_buftypes,
        filetypes = ibl_excluded_filetypes,
      },
    })
  end
)

-- ┌───────────────────────────────────────────┐
-- │ Setup virt-column                         │
-- └───────────────────────────────────────────┘

Lib.later(function()
  local virt_column = require('virt-column')

  virt_column.setup({
    char = '│',
    highlight = 'VirtColumn',
    exclude = {
      buftypes = excluded_buftypes,
      filetypes = excluded_ui_filetypes,
    },
  })
end)

-- ┌───────────────────────────────────────────┐
-- │ Setup render-markdown                     │
-- └───────────────────────────────────────────┘

Lib.later(
  function()
    require('render-markdown').setup({
      anti_conceal = {
        enabled = false,
      },
      debounce = 0,
      win_options = {
        concealcursor = {
          rendered = 'n',
        },
      },
      heading = {
        sign = false,
        icons = {},
        right_pad = 1,
        border = true,
        above = '',
        below = '―',
        border_virtual = true,
      },
      bullet = {
        icons = { '•', '◦' },
        left_pad = 2,
      },
      code = {
        sign = false,
        language = false,
        left_margin = 4,
        left_pad = 1,
        language_pad = 1,
        right_pad = 1,
      },
      pipe_table = {
        border_virtual = true,
      },
      indent = {
        enabled = true,
        icon = '',
      },
      latex = {
        enabled = false,
      },
      injections = {
        gitcommit = {
          enabled = false,
        },
      },
      overrides = {
        buftype = {
          nofile = {
            render_modes = true,
            padding = { highlight = 'NormalFloat' },
            sign = { enabled = false },
            code = {
              left_margin = 0,
              left_pad = 0,
              right_pad = 0,
            },
          },
        },
      },
    })
  end
)

return M
