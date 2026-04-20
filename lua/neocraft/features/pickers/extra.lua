local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local core = require('neocraft.features.pickers.core')

-- LSP locations picker helpers

---@class neocraft.pickers.lsp_location_item: vim.quickfix.entry
---@field location lsp.Location|lsp.LocationLink

---@class neocraft.pickers.LspLocationOpts
---@field title? string
---@field position_encoding? string

local function lsp_location_compare(a, b)
  local a_path = a.filename or ''
  local b_path = b.filename or ''
  if a_path ~= b_path then return a_path < b_path end

  local a_lnum = a.lnum or 1
  local b_lnum = b.lnum or 1
  if a_lnum ~= b_lnum then return a_lnum < b_lnum end

  local a_col = a.col or 1
  local b_col = b.col or 1
  if a_col ~= b_col then return a_col < b_col end

  return (a.text or '') < (b.text or '')
end

local function lsp_location_text(item)
  local path = item.filename or ''
  path = path == '' and ('Buffer_' .. tostring(item.bufnr or '?')) or vim.fn.fnamemodify(path, ':p:.')

  local suffix = item.text == nil or item.text == '' and '' or ('│ ' .. item.text)
  return string.format('%s│%s│%s%s', path, item.lnum or 1, item.col or 1, suffix)
end

-- Autocommands picker helpers

local function autocmd_pattern(autocmd)
  if autocmd.pattern and autocmd.pattern ~= '' then return autocmd.pattern end
  if autocmd.buffer and autocmd.buffer ~= 0 then return 'buffer:' .. autocmd.buffer end
  return '*'
end

local function autocmd_callback_location(callback)
  if type(callback) ~= 'function' then return nil end

  local info = debug.getinfo(callback, 'S')
  if not info or type(info.source) ~= 'string' or info.source:sub(1, 1) ~= '@' then return nil, info end

  return {
    path = info.source:sub(2),
    start = info.linedefined,
    finish = info.lastlinedefined,
  }, info
end

local function autocmd_display(autocmd)
  local group = autocmd.group_name or 'None'
  local event = autocmd.event or 'Unknown'
  local pattern = autocmd_pattern(autocmd)
  local desc = autocmd.desc or ''

  return string.format('%-4s %-22s %-18s %-28s %s', autocmd.id or '-', group, event, pattern, desc)
end

local function autocmd_items()
  local items = vim.tbl_map(
    function(autocmd)
      return {
        autocmd = autocmd,
        text = autocmd_display(autocmd),
      }
    end,
    vim.api.nvim_get_autocmds({})
  )

  table.sort(items, function(a, b)
    if a.text == b.text then return (a.autocmd.id or 0) < (b.autocmd.id or 0) end
    return a.text < b.text
  end)

  return items
end

local function autocmd_preview(buf_id, item)
  if type(item) ~= 'table' or type(item.autocmd) ~= 'table' then return end

  local autocmd = item.autocmd
  local callback_location, callback_info = autocmd_callback_location(autocmd.callback)
  local lines = {
    'Id: ' .. (autocmd.id or '-'),
    'Group: ' .. (autocmd.group_name or 'None'),
    'Event: ' .. (autocmd.event or 'Unknown'),
    'Pattern: ' .. autocmd_pattern(autocmd),
  }

  if autocmd.desc and autocmd.desc ~= '' then table.insert(lines, 'Description: ' .. autocmd.desc) end
  if autocmd.once then table.insert(lines, 'Once: true') end
  if autocmd.nested then table.insert(lines, 'Nested: true') end

  table.insert(lines, '')

  if autocmd.command and autocmd.command ~= '' then
    table.insert(lines, 'Command:')
    table.insert(lines, autocmd.command)
  elseif callback_location then
    table.insert(lines, 'Callback:')
    table.insert(lines, callback_location.path .. ':' .. callback_location.start)

    local ok, file_lines = pcall(vim.fn.readfile, callback_location.path)
    if ok then
      local start = math.max(callback_location.start, 1)
      local finish = math.min(callback_location.finish, start + 40)

      table.insert(lines, '')
      table.insert(lines, 'Source:')
      for lnum = start, finish do
        if file_lines[lnum] ~= nil then table.insert(lines, string.format('%4d: %s', lnum, file_lines[lnum])) end
      end

      if callback_location.finish > finish then table.insert(lines, '...') end
    end
  elseif callback_info then
    table.insert(lines, 'Callback:')
    vim.list_extend(lines, vim.split(vim.inspect(callback_info), '\n'))
  else
    table.insert(lines, 'Action: <none>')
  end

  vim.bo[buf_id].filetype = 'text'
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
end

local function autocmd_choose(item)
  if type(item) ~= 'table' or type(item.autocmd) ~= 'table' then return end

  local location = autocmd_callback_location(item.autocmd.callback)
  if not location then return end

  local state = require('mini.pick').get_picker_state()
  local target = state and state.windows.target or nil
  if not (target and vim.api.nvim_win_is_valid(target)) then return end

  vim.api.nvim_win_call(target, function()
    vim.cmd('edit ' .. vim.fn.fnameescape(location.path))
    vim.api.nvim_win_set_cursor(0, { math.max(location.start, 1), 0 })
  end)
end

-- Registry picker helpers

local function registry_picker_names()
  local excluded = { list = true, lsp = true }
  local names = vim.tbl_filter(
    function(name) return not excluded[name] end,
    vim.tbl_keys(require('mini.pick').registry)
  )
  table.sort(names)
  return names
end

local registry_builtin_runners = {
  files = function(buf) return core.files(buf) end,
  grep = function(buf) return core.builtin('grep', nil, { buf = buf }) end,
  grep_live = function(buf) return core.grep_live(buf) end,
  resume = function() return core.resume() end,
}

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

---@param locations (lsp.Location|lsp.LocationLink)[]
---@param opts? neocraft.pickers.LspLocationOpts
function M.lsp_locations(locations, opts)
  local mini_pick = require('mini.pick')

  opts = vim.tbl_deep_extend('force', {
    title = 'LSP Locations',
    position_encoding = 'utf-16',
  }, opts or {})

  local quickfix_items = vim.lsp.util.locations_to_items(locations, opts.position_encoding)
  ---@type neocraft.pickers.lsp_location_item[]
  local items = {}
  for index, item in ipairs(quickfix_items) do
    local location_item = vim.tbl_extend('force', item, {
      location = locations[index],
      path = item.filename,
      text = lsp_location_text(item),
    })
    ---@cast location_item neocraft.pickers.lsp_location_item
    items[index] = location_item
  end

  table.sort(items, lsp_location_compare)

  return mini_pick.start({
    source = {
      items = items,
      name = opts.title,
      preview = mini_pick.default_preview,
      choose = function(item)
        if type(item) ~= 'table' or item.location == nil then return end

        local state = mini_pick.get_picker_state()
        local target = state and state.windows.target or nil
        local open = function()
          vim.lsp.util.show_document(item.location, opts.position_encoding, {
            focus = true,
            reuse_win = true,
          })
          vim.cmd('normal! zz')
        end

        if target and vim.api.nvim_win_is_valid(target) then
          vim.api.nvim_win_call(target, open)
          return
        end

        open()
      end,
    },
  })
end

-- Starts 'autocmds' custom picker, showing registered autocommands.
function M.autocmds()
  return require('mini.pick').start({
    source = {
      items = autocmd_items,
      name = 'Autocommands',
      preview = autocmd_preview,
      choose = autocmd_choose,
    },
  })
end

-- Start a picker to select a built-in or public custom registered picker from the mini.pick registry.
function M.registry()
  local mini_pick = require('mini.pick')
  local public_custom_pickers = require('neocraft.plugins.mini.pick').public_custom_pickers

  mini_pick.start({
    source = {
      items = registry_picker_names,
      name = 'Pickers',
      choose = function(item)
        local state = mini_pick.get_picker_state()
        local target_win = state and state.windows.target or nil
        local target_buf = target_win and vim.api.nvim_win_is_valid(target_win) and vim.api.nvim_win_get_buf(target_win)
          or 0
        local picker = mini_pick.registry[item]
        local runner = registry_builtin_runners[item] or public_custom_pickers[item]
        local run = runner and function() runner(target_buf) end
          or function()
            if type(picker) ~= 'function' then
              vim.notify('Unknown picker: ' .. item, vim.log.levels.ERROR)
              return
            end

            picker()
          end

        vim.schedule(run)
      end,
    },
  })
end

return M
