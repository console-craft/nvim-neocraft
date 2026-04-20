-- Theme highlight helpers for setting and linking highlight groups.

local M = {}

-- Link one highlight group to another, making it inherit the same styles and colors.
function M.link(from, to) vim.api.nvim_set_hl(0, from, { link = to }) end

-- Set the styles and colors for a highlight group.
function M.set(hl, fg, bg, opts)
  local ok, original = pcall(vim.api.nvim_get_hl, 0, { name = hl, link = false })
  local new = {}
  local o = opts or {}

  if fg ~= nil then new.fg = fg end
  if bg ~= nil then new.bg = bg end
  if o.bold ~= nil then new.bold = o.bold end
  if o.italic ~= nil then new.italic = o.italic end
  if o.strikethrough ~= nil then new.strikethrough = o.strikethrough end
  if o.underline ~= nil then new.underline = o.underline end
  if o.undercurl ~= nil then new.undercurl = o.undercurl end
  if o.underdotted ~= nil then new.underdotted = o.underdotted end
  if o.underdashed ~= nil then new.underdashed = o.underdashed end
  if o.sp ~= nil then new.sp = o.sp end

  vim.api.nvim_set_hl(0, hl, vim.tbl_extend('force', ok and original or {}, new))
end

return M
