-- Start SonarLint clients only for projects selected by Neocraft's project policy.

local M = {}

local policy = require('neocraft.features.lsp.sonarlint')
local utils = require('sonarlint.utils')
local scm = require('sonarlint.scm')
local autobinding = require('sonarlint.autobinding')
local rules = require('sonarlint.rules')
local connected_mode = require('sonarlint.connected_mode')

local server_versions = {}

-- Merge settings into a running client before notifying the server.
local function update_settings(client, settings)
  client.settings = vim.tbl_deep_extend('force', client.settings or {}, settings)
end

local function missing_requirements_handler(_, _, ctx)
  local version = server_versions[ctx.client_id]
  if version and (version.major > 4 or (version.major == 4 and version.minor >= 7)) then return 'error_only' end

  return false
end

local function ready_handler(_, _, ctx)
  local mode = connected_mode.configured_with_connected_mode(ctx.client_id) and 'connected' or 'local'
  vim.notify_once('SonarQube language server is ready and running in ' .. mode .. ' mode.', vim.log.levels.INFO)
end

local function deactivate_rule(action, ctx)
  local rule = action.arguments and action.arguments[1]
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if rule == nil or client == nil then return end

  update_settings(client, {
    sonarlint = {
      rules = {
        [rule] = { level = 'off' },
      },
    },
  })
  client:notify('workspace/didChangeConfiguration', { settings = {} })
end

local function show_all_locations(result)
  local items = {}

  for _, argument in ipairs(result.arguments or {}) do
    local bufnr = vim.uri_to_bufnr(argument.fileUri)

    for _, flow in ipairs(argument.flows or {}) do
      for _, location in ipairs(flow.locations or {}) do
        local range = location.textRange
        table.insert(items, {
          bufnr = bufnr,
          lnum = range.startLine,
          col = range.startLineOffset,
          end_lnum = range.endLine,
          end_col = range.endLineOffset,
          text = argument.message,
        })
      end
    end
  end

  vim.fn.setqflist(items, 'r')
  vim.cmd.copen()
end

local function connection_result_handler(url)
  return function(_, params, ctx)
    local status = params.success == true and 'connected' or 'failed-connection'
    connected_mode._connected_clients[ctx.client_id] = status

    if params.success == true then
      vim.notify_once('Connected to ' .. url .. ' (' .. params.connectionId .. ')', vim.log.levels.DEBUG)
      return
    end

    vim.notify_once(
      'Cannot connect to ' .. url .. ' (' .. params.connectionId .. '): ' .. (params.reason or 'unknown error'),
      vim.log.levels.ERROR
    )
  end
end

local function invalid_token_handler(url)
  return function(_, params)
    vim.notify(
      'Cannot connect to ' .. url .. '. Invalid token for connection ' .. params.connectionId,
      vim.log.levels.WARN
    )
  end
end

local function handlers(connection_url)
  local result = {
    ['sonarlint/canShowMissingRequirementsNotification'] = missing_requirements_handler,
    ['sonarlint/isOpenInEditor'] = function(_, uri) return utils.is_open_in_editor(uri[1]) end,
    ['sonarlint/shouldAnalyseFile'] = function(_, uri) return { shouldBeAnalysed = utils.is_open_in_editor(uri.uri) } end,
    ['sonarlint/readyForTests'] = ready_handler,
    ['sonarlint/settingsApplied'] = ready_handler,
    ['sonarlint/isIgnoredByScm'] = scm.is_ignored_by_scm,
    ['sonarlint/listFilesInFolder'] = autobinding.list_autobinding_files_in_folder,
    ['sonarlint/filterOutExcludedFiles'] = function(_, params) return params end,
    ['sonarlint/hasJoinedIdeLabs'] = function() return false end,
    ['sonarlint/showRuleDescription'] = rules.show_rule_handler,
  }

  if connection_url then
    result['sonarlint/getTokenForServer'] = function(err, params, ctx)
      return connected_mode.get_token_for_server(err, params, ctx) or vim.NIL
    end
    result['sonarlint/notifyInvalidToken'] = invalid_token_handler(connection_url)
    result['sonarlint/reportConnectionCheckResult'] = connection_result_handler(connection_url)
  end

  return result
end

local function commands(use_connected_mode)
  local result = {
    ['SonarLint.DeactivateRule'] = deactivate_rule,
    ['SonarLint.ShowAllLocations'] = show_all_locations,
  }

  if use_connected_mode then result['SonarLint.ResolveIssue'] = connected_mode.resolve_issue end
  return result
end

local function should_use_connected_mode(connected, project)
  return project.mode ~= 'local' and connected.has_credentials(project.connection_id)
end

local function client_config(server, connected, project)
  local connection = connected.connections[project.connection_id]
  if connection == nil then return nil end

  local config = vim.deepcopy(server)
  local uname = vim.uv.os_uname()
  local connections
  local use_connected_mode = should_use_connected_mode(connected, project)

  if connection.kind == 'sonarcloud' then
    connections = {
      sonarcloud = {
        {
          connectionId = project.connection_id,
          organizationKey = connection.organization_key,
          region = connection.region,
          disableNotifications = false,
        },
      },
    }
  elseif connection.kind == 'sonarqube' then
    connections = {
      sonarqube = {
        {
          connectionId = project.connection_id,
          serverUrl = connection.url,
          disableNotifications = false,
        },
      },
    }
  else
    return nil
  end

  config.name = 'sonarlint.nvim'
  config.root_dir = project.root_dir
  config.capabilities = config.capabilities or vim.lsp.protocol.make_client_capabilities()
  if use_connected_mode then
    config.connected = { get_credentials = connected.get_credentials }
    config.settings = vim.tbl_deep_extend('force', config.settings or {}, {
      sonarlint = {
        connectedMode = {
          connections = connections,
          project = {
            connectionId = project.connection_id,
            projectKey = project.project_key,
          },
        },
      },
    })
  end
  config.init_options = vim.tbl_deep_extend('keep', config.init_options or {}, {
    productKey = 'sonarlint.nvim',
    productName = 'SonarLint.nvim',
    productVersion = '0.1.0',
    workspaceName = vim.fs.basename(project.root_dir),
    firstSecretDetected = false,
    showVerboseLogs = true,
    platform = uname.sysname,
    architecture = uname.machine,
  })
  config.handlers =
    vim.tbl_extend('force', config.handlers or {}, handlers(use_connected_mode and connection.url or nil))
  config.commands = vim.tbl_extend('force', config.commands or {}, commands(use_connected_mode))

  local original_on_init = config.on_init
  config.on_init = function(client, result)
    local version = result.serverInfo and result.serverInfo.version
    local major, minor
    if type(version) == 'string' then
      major, minor = version:match('^(%d+)%.(%d+)')
    end
    if major ~= nil and minor ~= nil then
      server_versions[client.id] = { major = tonumber(major), minor = tonumber(minor) }
    end

    if original_on_init then original_on_init(client, result) end
  end

  local original_on_exit = config.on_exit
  config.on_exit = function(code, signal, client_id)
    server_versions[client_id] = nil
    connected_mode._connected_clients[client_id] = nil
    if original_on_exit then original_on_exit(code, signal, client_id) end
  end

  return config
end

-- Register project-gated SonarLint startup and SCM notifications.
function M.setup(config)
  local group = Lib.augroup('sonarlint')

  Lib.autocmd('FileType', {
    group = group,
    pattern = config.filetypes,
    desc = 'Start SonarLint for configured projects',
    callback = function(args)
      local project = policy.resolve(config.projects, args.buf)
      if project == nil then return end

      local client = client_config(config.server, config.connected, project)
      if client == nil then
        vim.notify('Missing SonarLint connection: ' .. project.connection_id, vim.log.levels.ERROR)
        return
      end

      vim.lsp.start(client, { bufnr = args.buf })
    end,
  })

  Lib.autocmd({ 'BufEnter', 'LspAttach' }, {
    group = group,
    desc = 'Notify SonarLint when the Git branch changes',
    callback = scm.check_git_branch_and_notify_lsp,
  })

  if vim.fn.exists(':SonarLintInfo') ~= 2 then
    vim.api.nvim_create_user_command('SonarLintInfo', function()
      local project = policy.resolve(config.projects, 0)
      if project == nil then
        vim.notify('SonarLint is not configured for the current buffer', vim.log.levels.INFO)
        return
      end

      vim.notify(
        table.concat({
          'SonarLint project',
          'Root: ' .. project.root_dir,
          'Mode: ' .. (should_use_connected_mode(config.connected, project) and 'connected' or 'local'),
          'Connection: ' .. project.connection_id,
          'Project: ' .. project.project_key,
        }, '\n'),
        vim.log.levels.INFO
      )
    end, { desc = 'Show SonarLint configuration for the current buffer' })
  end
end

return M
