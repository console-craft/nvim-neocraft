-- Configure mini.completion.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local function snippet_to_plain_text(snippet)
  if type(snippet) ~= 'string' or snippet == '' then return snippet end

  local text = snippet
  local previous

  repeat
    previous = text
    text = text:gsub('%${%d+|([^,|}]+)[^}]*|}', '%1')
    text = text:gsub('%${%d+:([^{}]*)}', '%1')
  until text == previous

  text = text:gsub('%${%d+}', '')
  text = text:gsub('%$%d+', '')
  text = text:gsub('%${[%a_][%w_]*:([^{}]*)}', '%1')
  text = text:gsub('%${[%a_][%w_]*}', '')
  text = text:gsub('%$[%a_][%w_]*', '')
  text = text:gsub('\\([\\}$])', '%1')

  return text
end

local function plain_text_extra_edit_snippets(items)
  local snippet_kind = vim.lsp.protocol.CompletionItemKind.Snippet
  local snippet_format = vim.lsp.protocol.InsertTextFormat.Snippet
  local plain_text_format = vim.lsp.protocol.InsertTextFormat.PlainText

  for _, item in ipairs(items) do
    local is_snippet = item.kind == snippet_kind or item.insertTextFormat == snippet_format

    if is_snippet and item.additionalTextEdits ~= nil then
      item.insertTextFormat = plain_text_format

      if type(item.textEdit) == 'table' and type(item.textEdit.newText) == 'string' then
        item.textEdit.newText = snippet_to_plain_text(item.textEdit.newText)
      end

      if type(item.insertText) == 'string' then item.insertText = snippet_to_plain_text(item.insertText) end
      if type(item.textEditText) == 'string' then item.textEditText = snippet_to_plain_text(item.textEditText) end
    end
  end
end

local process_items_opts = { kind_priority = { Text = -1, Snippet = 99 } }

local process_items = function(items, base)
  plain_text_extra_edit_snippets(items)
  return require('mini.completion').default_process_items(items, base, process_items_opts)
end

-- ┌───────────────────────────────────────────┐
-- │ Setup Mini Completion                     │
-- └───────────────────────────────────────────┘

Lib.now(
  function()
    require('mini.completion').setup({
      lsp_completion = {
        auto_setup = false,
        source_func = 'omnifunc',
        process_items = process_items,
      },
      mappings = {
        force_twostep = '',
      },
      window = {
        info = { border = vim.o.winborder },
        signature = { border = vim.o.winborder },
      },
    })
  end
)

return M
