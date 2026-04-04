local root = require('neocraft.core.root')

local M = {}

local state = {
  buf = nil,
  win = nil,
}

local function clamp(value, min, max) return math.min(math.max(value, min), max) end

local function is_running(buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then return false end

  local job = vim.b[buf].terminal_job_id
  return type(job) == 'number' and vim.fn.jobwait({ job }, 0)[1] == -1
end

---@return integer
local function ensure_buf()
  local buf = state.buf
  if type(buf) == 'number' and vim.api.nvim_buf_is_valid(buf) and is_running(buf) then return buf end

  buf = vim.api.nvim_create_buf(false, true)
  state.buf = buf
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  return buf
end

local function win_config()
  local columns = vim.o.columns
  local lines = vim.o.lines
  local width = clamp(math.floor(columns * 0.90), 80, 180)
  local height = clamp(math.floor(lines * 0.75), 25, 50)

  width = math.min(width, columns - 4)
  height = math.min(height, lines - 2)

  return {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((columns - width) * 0.5),
    row = math.floor((lines - height) * 0.5),
    style = 'minimal',
    border = 'rounded',
  }
end

local function start_job(buf)
  local cwd = root.get()

  vim.api.nvim_buf_call(buf, function() vim.fn.jobstart(vim.o.shell, { cwd = cwd, term = true }) end)

  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
end

function M.open()
  local buf = ensure_buf()
  state.win = vim.api.nvim_open_win(buf, true, win_config())

  if not is_running(buf) then start_job(buf) end

  vim.cmd.startinsert()
end

function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then vim.api.nvim_win_hide(state.win) end
end

function M.toggle()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    M.close()
    return
  end

  M.open()
end

vim.api.nvim_create_user_command('NeocraftTerminal', function() M.toggle() end, {
  desc = 'Toggle Neocraft floating terminal',
})

return M
