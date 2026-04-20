-- Overrides settings from the default vtsls LSP config provided by nvim-lspconfig.
--
--  * Enables richer JavaScript and TypeScript completions, including function-call snippets and fuzzy server-side matching.
--  * Keeps import updates and move-to-file refactors enabled for file rename and extraction workflows.
--  * Enables inlay hints and code lenses for references and implementations with slightly tighter hint display limits.
--
-- DOCS: https://github.com/neovim/nvim-lspconfig/blob/master/lsp/vtsls.lua

-- ┌───────────────────────────────────────────┐
-- │ Setup                                     │
-- └───────────────────────────────────────────┘

local language_settings = {
  suggest = {
    completeFunctionCalls = true,
  },
  tsserver = {
    -- log = 'verbose', -- Only enable when debugging.
  },
  updateImportsOnFileMove = {
    enabled = 'always',
  },
  inlayHints = {
    enumMemberValues = {
      enabled = true,
    },
    functionLikeReturnTypes = {
      enabled = true,
    },
    parameterNames = {
      enabled = 'literals',
    },
    parameterTypes = {
      enabled = true,
    },
    propertyDeclarationTypes = {
      enabled = true,
    },
    variableTypes = {
      enabled = false,
    },
  },
  referencesCodeLens = { enabled = true, showOnAllFunctions = true },
  implementationsCodeLens = { enabled = true },
}

-- ┌───────────────────────────────────────────┐
-- │ LSP config                                │
-- └───────────────────────────────────────────┘

return {
  settings = {
    complete_function_calls = true,
    vtsls = {
      autoUseWorkspaceTsdk = true,
      enableMoveToFileCodeAction = true,
      experimental = {
        completion = {
          enableServerSideFuzzyMatch = true,
        },
        maxInlayHintLength = 30,
      },
    },
    javascript = vim.deepcopy(language_settings),
    typescript = language_settings,
  },
}
