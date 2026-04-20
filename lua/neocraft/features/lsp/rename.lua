-- Notify attached LSP clients about file moves triggered from mini.files.

local group = Lib.augroup('lsp-rename')

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

-- Normalize a filesystem path or return nil for invalid input.
local function normalize_path(path)
  if type(path) ~= 'string' or path == '' then return nil end
  return vim.fs.normalize(path)
end

-- Check whether a normalized path is equal to or nested under a root directory.
local function path_is_within(path, root_dir)
  path = normalize_path(path)
  root_dir = normalize_path(root_dir)
  if not path or not root_dir then return false end
  if path == root_dir then return true end
  return vim.startswith(path, root_dir .. '/')
end

-- Collect unique workspace roots and attached buffer paths for an LSP client.
local function client_roots(client)
  local roots = {}
  local seen = {}

  local function add(path)
    path = normalize_path(path)
    if not path or seen[path] then return end
    seen[path] = true
    table.insert(roots, path)
  end

  for _, folder in ipairs(client.workspace_folders or {}) do
    if type(folder.uri) == 'string' and folder.uri ~= '' then add(vim.uri_to_fname(folder.uri)) end
  end

  if type(client.root_dir) == 'string' then add(client.root_dir) end
  if type(client.config.root_dir) == 'string' then add(client.config.root_dir) end

  for buf in pairs(client.attached_buffers or {}) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= '' then add(name) end
  end

  return roots
end

-- Check whether a client appears to manage the given path.
local function client_handles_path(client, path)
  for _, root_dir in ipairs(client_roots(client)) do
    if path_is_within(path, root_dir) then return true end
  end

  return false
end

-- Build LSP rename notification parameters for a moved file.
local function rename_params(from, to)
  return {
    files = {
      {
        oldUri = vim.uri_from_fname(from),
        newUri = vim.uri_from_fname(to),
      },
    },
  }
end

-- Send willRename and didRename notifications to clients affected by a file move.
local function notify_lsp_file_rename(from, to)
  from = normalize_path(from)
  to = normalize_path(to)
  if not from or not to or from == to then return end

  local params = rename_params(from, to)

  for _, client in ipairs(vim.lsp.get_clients()) do
    if client_handles_path(client, from) or client_handles_path(client, to) then
      if client:supports_method('workspace/willRenameFiles') then
        local response = client:request_sync('workspace/willRenameFiles', params, 1000)
        if response and response.result then
          vim.lsp.util.apply_workspace_edit(response.result, client.offset_encoding)
        end
      end

      if client:supports_method('workspace/didRenameFiles') then client:notify('workspace/didRenameFiles', params) end
    end
  end
end

Lib.autocmd('User', {
  group = group,
  pattern = { 'MiniFilesActionRename', 'MiniFilesActionMove' },
  desc = 'Notify LSP clients after mini.files rename and move actions',
  callback = function(args)
    local data = args.data or {}
    notify_lsp_file_rename(data.from, data.to)
  end,
})
