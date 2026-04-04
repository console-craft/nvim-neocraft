local function has_project_luarc(root_dir)
  if type(root_dir) ~= 'string' or root_dir == '' then return false end

  return vim.uv.fs_stat(root_dir .. '/.luarc.json') ~= nil or vim.uv.fs_stat(root_dir .. '/.luarc.jsonc') ~= nil
end

return {
  on_init = function(client)
    local workspace = client.workspace_folders and client.workspace_folders[1]
    local root_dir = workspace and workspace.name or nil

    if root_dir ~= vim.fn.stdpath('config') and has_project_luarc(root_dir) then return end

    client.config.settings = client.config.settings or {}
    client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua or {}, {
      runtime = {
        version = 'LuaJIT',
        path = { 'lua/?.lua', 'lua/?/init.lua' },
      },
      workspace = {
        checkThirdParty = false,
        library = {
          vim.env.VIMRUNTIME,
          '${3rd}/luv/library',
        },
      },
      diagnostics = {
        globals = { 'Lib' },
      },
    })
  end,
  settings = {
    Lua = {
      codeLens = {
        enable = true,
      },
      completion = {
        callSnippet = 'Replace',
      },
      doc = {
        privateName = { '^_' },
      },
      hint = {
        enable = true,
        arrayIndex = 'Disable',
        paramName = true,
        paramType = true,
        semicolon = 'Disable',
        setType = false,
      },
    },
  },
}
