-- Git rebase workflows.

local M = {}

local util = require('neocraft.features.git.util')

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Start an interactive rebase from a prompted starting point.
function M.rebase_interactive()
  vim.ui.input({
    prompt = 'Rebase starting poin (use "root" to include first commit):',
  }, function(input)
    if input == nil then return end

    local start = vim.trim(input)
    if start == '' then return end

    if start == 'root' then
      util.git('rebase -i --root')
      return
    end

    util.git('rebase -i ' .. util.git_escape(start))
  end)
end

-- Continue an in-progress rebase.
function M.rebase_continue() util.git('rebase --continue') end

-- Skip the current rebase commit.
function M.rebase_skip() util.git('rebase --skip') end

-- Abort the current rebase.
function M.rebase_abort() util.git('rebase --abort') end

return M
