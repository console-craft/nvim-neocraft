-- Git cherry-pick workflows.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local util = require('neocraft.features.git.util')

-- Split whitespace-separated commit arguments and escape each one.
local function split_git_args(input) return vim.tbl_map(util.git_escape, vim.split(input, '%s+', { trimempty = true })) end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Prompt for one or more commits and cherry-pick them.
function M.cherry_pick()
  vim.ui.input({
    prompt = 'Cherry-pick commit sha(s):',
  }, function(input)
    if input == nil then return end

    local commits = split_git_args(vim.trim(input))
    if #commits == 0 then return end

    util.git('cherry-pick ' .. table.concat(commits, ' '))
  end)
end

-- Continue an in-progress cherry-pick.
function M.cherry_pick_continue() util.git('cherry-pick --continue') end

-- Skip the current cherry-pick commit.
function M.cherry_pick_skip() util.git('cherry-pick --skip') end

-- Abort the current cherry-pick.
function M.cherry_pick_abort() util.git('cherry-pick --abort') end

return M
