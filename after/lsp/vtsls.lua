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
