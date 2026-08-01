-- Configure the SonarLint integration.

local M = {}

Lib.now(function()
  local sonarlint = require('neocraft.features.lsp.sonarlint_client')
  local mason_root = vim.env.MASON
  if mason_root == nil or mason_root == '' then mason_root = vim.fs.joinpath(vim.fn.stdpath('data'), 'mason') end
  local analyzer_dir = vim.fs.joinpath(mason_root, 'share', 'sonarlint-analyzers')

  local function env(name)
    local value = vim.env[name]
    return value ~= nil and value ~= '' and value or nil
  end

  local connections = {}
  local personal_url = env('SONAR_PERSONAL_URL')
  local personal_organization = env('SONAR_PERSONAL_ORGANIZATION')
  local personal_region = env('SONAR_PERSONAL_REGION')
  if personal_url and personal_organization and personal_region then
    connections['personal-sonarcloud'] = {
      kind = 'sonarcloud',
      url = personal_url,
      organization_key = personal_organization,
      region = personal_region,
      token_env = 'SONAR_PERSONAL_TOKEN',
    }
  end

  local work_url = env('SONAR_WORK_URL')
  if work_url then
    connections['work-sonarqube'] = {
      kind = 'sonarqube',
      url = work_url,
      token_env = 'SONAR_WORK_TOKEN',
    }
  end

  local projects = {}
  local function add_project(connection_id, remote, path, project_key, mode)
    if connections[connection_id] == nil or remote == nil or path == nil or project_key == nil then return end

    table.insert(projects, {
      remotes = { remote },
      path = path,
      connection_id = connection_id,
      project_key = project_key,
      mode = mode,
    })
  end

  local personal_remote = env('SONAR_PERSONAL_REPOSITORY')
  add_project(
    'personal-sonarcloud',
    personal_remote,
    env('SONAR_PERSONAL_FRONTEND_PATH'),
    env('SONAR_PERSONAL_FRONTEND_PROJECT_KEY'),
    env('SONAR_PERSONAL_FRONTEND_MODE')
  )
  add_project(
    'personal-sonarcloud',
    personal_remote,
    env('SONAR_PERSONAL_BACKEND_PATH'),
    env('SONAR_PERSONAL_BACKEND_PROJECT_KEY'),
    env('SONAR_PERSONAL_BACKEND_MODE')
  )

  local work_remote = env('SONAR_WORK_REPOSITORY')
  add_project(
    'work-sonarqube',
    work_remote,
    env('SONAR_WORK_FRONTEND_PATH'),
    env('SONAR_WORK_FRONTEND_PROJECT_KEY'),
    env('SONAR_WORK_FRONTEND_MODE')
  )
  add_project(
    'work-sonarqube',
    work_remote,
    env('SONAR_WORK_BACKEND_PATH'),
    env('SONAR_WORK_BACKEND_PROJECT_KEY'),
    env('SONAR_WORK_BACKEND_MODE')
  )

  sonarlint.setup({
    connected = {
      connections = connections,
      has_credentials = function(connection_id)
        local connection = connections[connection_id]
        if connection == nil then return false end

        local token = vim.env[connection.token_env]
        return token ~= nil and token ~= ''
      end,
      get_credentials = function(_, credential)
        local selected
        for _, connection in pairs(connections) do
          if connection.kind == 'sonarcloud' then
            if credential == connection.region .. '_' .. connection.organization_key then selected = connection end
          elseif connection.kind == 'sonarqube' then
            if credential:gsub('/+$', '') == connection.url:gsub('/+$', '') then selected = connection end
          end
        end
        if selected == nil then
          vim.notify('Refusing to provide Sonar token for unexpected connection: ' .. credential, vim.log.levels.ERROR)
          return nil
        end

        local token = vim.env[selected.token_env]
        if not token or token == '' then
          vim.notify(selected.token_env .. ' is not available', vim.log.levels.ERROR)
          return nil
        end

        return token
      end,
    },
    server = {
      cmd = {
        'sonarlint-language-server',
        '-stdio',
        '-analyzers',
        vim.fs.joinpath(analyzer_dir, 'sonarpython.jar'),
        vim.fs.joinpath(analyzer_dir, 'sonarjs.jar'),
        vim.fs.joinpath(analyzer_dir, 'sonarhtml.jar'),
        vim.fs.joinpath(analyzer_dir, 'sonariac.jar'),
        vim.fs.joinpath(analyzer_dir, 'sonartext.jar'),
      },
    },
    projects = projects,
    filetypes = {
      'javascript',
      'javascriptreact',
      'typescript',
      'typescriptreact',
      'python',
      'html',
      'dockerfile',
      'yaml',
    },
  })
end)

return M
