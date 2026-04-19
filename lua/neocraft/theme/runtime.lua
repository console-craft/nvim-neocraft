local util = require('neocraft.theme.util')

local M = {}

local set = util.set

local group = Lib.augroup('theme-runtime')

local function mode_name()
  local first = vim.api.nvim_get_mode().mode:byte(1)

  if
    first == string.byte('v')
    or first == string.byte('V')
    or first == 22
    or first == string.byte('s')
    or first == string.byte('S')
    or first == 19
  then
    return 'select'
  end

  if first == string.byte('R') or first == string.byte('r') then return 'replace' end
  if first == string.byte('c') then return 'command' end
  if first == string.byte('i') or first == string.byte('I') then return 'insert' end
  return 'normal'
end

local function active_winbar_bg(colors, mode)
  local colors_by_mode = {
    normal = colors.blue,
    insert = colors.green,
    select = colors.yellow,
    replace = colors.red,
    command = colors.orange,
  }

  return colors_by_mode[mode] or colors.blue
end

local function apply_winbar(spec, mode)
  if vim.g.colors_name ~= spec.name then return end
  set('WinBar', spec.colors.black, active_winbar_bg(spec.colors, mode or mode_name()), { bold = true })
end

local function redraw_winbar()
  if vim.api.nvim__redraw ~= nil then
    pcall(vim.api.nvim__redraw, {
      win = vim.api.nvim_get_current_win(),
      winbar = true,
      flush = true,
      valid = false,
    })
    return
  end

  pcall(function() vim.cmd('redrawstatus') end)
end

function M.setup(spec)
  vim.api.nvim_clear_autocmds({ group = group })
  apply_winbar(spec)

  Lib.autocmd({ 'ModeChanged', 'WinEnter', 'BufWinEnter', 'ColorScheme' }, {
    group = group,
    desc = 'Update active WinBar for gruvcraft mode changes',
    callback = function()
      vim.schedule(function()
        apply_winbar(spec)
        redraw_winbar()
      end)
    end,
  })

  Lib.autocmd('CmdlineEnter', {
    group = group,
    desc = 'Show command-mode WinBar for gruvcraft',
    callback = function()
      apply_winbar(spec, 'command')
      redraw_winbar()
    end,
  })

  Lib.autocmd('CmdlineLeave', {
    group = group,
    desc = 'Restore mode-aware WinBar after leaving command line',
    callback = function()
      vim.schedule(function() apply_winbar(spec) end)
    end,
  })
end

return M
