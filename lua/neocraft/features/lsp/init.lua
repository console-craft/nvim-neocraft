local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local annotations = require('neocraft.features.lsp.annotations')
local copilot = require('neocraft.features.lsp.copilot')
local typescript = require('neocraft.features.lsp.typescript')
local python = require('neocraft.features.lsp.python')
local attach = require('neocraft.features.lsp.attach')

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Show attached LSP clients and LSP info for the current buffer.
M.show_attached_clients = attach.show_attached_clients
M.lsp_info = attach.lsp_info

-- Show LSP definition in a vertical split.
M.definition_in_vsplit = attach.definition_in_vsplit

-- LSP client annotations.
M.reset_buffer_annotations = annotations.reset_buffer_annotations
M.toggle_inlay_hints = annotations.toggle_inlay_hints
M.toggle_codelens = annotations.toggle_codelens

-- Copilot LSP integration.
M.copilot_sign_in = copilot.copilot_sign_in
M.copilot_sign_out = copilot.copilot_sign_out
M.accept_inline_completion_to_eol = copilot.accept_inline_completion_to_eol
M.trigger_or_cycle_inline_completion = copilot.trigger_or_cycle_inline_completion

-- TypeScript-specific LSP helpers.
M.typescript_source_definition = typescript.typescript_source_definition
M.typescript_file_references = typescript.typescript_file_references
M.typescript_organize_imports = typescript.typescript_organize_imports
M.typescript_add_missing_imports = typescript.typescript_add_missing_imports
M.typescript_remove_unused_imports = typescript.typescript_remove_unused_imports
M.typescript_select_version = typescript.typescript_select_version
M.typescript_open_log = typescript.typescript_open_log
M.typescript_restart = typescript.typescript_restart

-- Python-specific LSP helpers.
M.python_organize_imports = python.python_organize_imports
M.python_select_venv = python.python_select_venv

return M
