-- Git hunk navigation, counts, and overlays.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local util = require('neocraft.features.git.util')

local inline_hunk_count_group = Lib.augroup('git_hunk_count')
local inline_hunk_count_ns = vim.api.nvim_create_namespace('neocraft_git_hunk_count')
local hunk_count_delay = 500

-- Find the range containing or following the current line.
local function current_range_idx(ranges, line)
  for i, range in ipairs(ranges) do
    if line >= range.start and line <= range.finish then return i end
  end

  for i, range in ipairs(ranges) do
    if line < range.start then return i end
  end

  return #ranges
end

-- Compute the ending buffer line for a diff hunk.
local function hunk_buf_end(hunk)
  local start = math.max(tonumber(hunk.buf_start) or 1, 1)
  local count = tonumber(hunk.buf_count) or 0
  if count <= 0 then return start end

  return math.max(start + count - 1, 1)
end

-- Merge diff hunks into contiguous buffer ranges.
local function get_hunk_ranges(hunks)
  local sorted = {}

  for _, hunk in ipairs(hunks) do
    table.insert(sorted, hunk)
  end

  table.sort(sorted, function(a, b) return (a.buf_start or 0) < (b.buf_start or 0) end)

  local ranges = {}
  for _, hunk in ipairs(sorted) do
    local start = math.max(tonumber(hunk.buf_start) or 1, 1)
    local finish = hunk_buf_end(hunk)
    local last = ranges[#ranges]

    if last == nil then
      ranges[1] = { start = start, finish = finish }
    elseif start <= last.finish + 1 then
      last.finish = math.max(last.finish, finish)
    else
      ranges[#ranges + 1] = { start = start, finish = finish }
    end
  end

  return ranges
end

-- Clear the temporary inline hunk count for a buffer.
local function clear_inline_hunk_count(buf)
  buf = util.resolve_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end

  vim.api.nvim_buf_clear_namespace(buf, inline_hunk_count_ns, 0, -1)
end

-- Show the current hunk index inline at the cursor line.
local function show_inline_hunk_count(buf)
  buf = util.resolve_buf(buf)
  clear_inline_hunk_count(buf)

  local mini_diff = require('mini.diff')
  local data = mini_diff.get_buf_data(buf)
  if data == nil or data.hunks == nil or #data.hunks == 0 then return end

  local ranges = get_hunk_ranges(data.hunks)
  if #ranges == 0 then return end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  local idx = current_range_idx(ranges, line)
  local text = ('    󰊢  [%d/%d]'):format(idx, #ranges)

  vim.api.nvim_buf_set_extmark(buf, inline_hunk_count_ns, line - 1, 0, {
    virt_text = { { text, 'DiagnosticWarn' } },
    virt_text_pos = 'eol',
    hl_mode = 'combine',
  })

  vim.api.nvim_clear_autocmds({ group = inline_hunk_count_group, buffer = buf })
  Lib.autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertEnter', 'BufLeave' }, {
    group = inline_hunk_count_group,
    buffer = buf,
    once = true,
    desc = 'Clear inline mini.diff hunk count',
    callback = function(args) clear_inline_hunk_count(args.buf) end,
  })
end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Move to a diff hunk and briefly show its position.
function M.goto_hunk(direction)
  local mini_diff = require('mini.diff')

  mini_diff.goto_hunk(direction, { n_times = vim.v.count1 })
  vim.cmd('normal! zz')

  local buf = vim.api.nvim_get_current_buf()
  vim.defer_fn(function()
    if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_get_current_buf() ~= buf then return end
    show_inline_hunk_count(buf)
  end, hunk_count_delay)
end

-- Toggle the mini.diff overlay for the current buffer.
function M.toggle_overlay()
  local bufnr = vim.api.nvim_get_current_buf()
  require('mini.diff').toggle_overlay(bufnr)
  require('neocraft.features.lsp').reset_buffer_annotations(bufnr)
end

return M
