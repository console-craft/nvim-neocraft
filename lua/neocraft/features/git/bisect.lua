-- Git bisect workflows.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local util = require('neocraft.features.git.util')

-- Prompt for a commit-ish and pass the trimmed value to a callback.
local function prompt_commit(prompt, callback)
  vim.ui.input({ prompt = prompt }, function(input)
    if input == nil then return end

    local commit = vim.trim(input)
    if commit == '' then return end

    callback(commit)
  end)
end

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Start a bisect session from prompted bad and good commits.
function M.bisect_start()
  prompt_commit('Bisect bad commit:', function(bad)
    prompt_commit(
      'Bisect good commit:',
      function(good) util.git('bisect start ' .. util.git_escape(bad) .. ' ' .. util.git_escape(good)) end
    )
  end)
end

-- Mark the current bisect commit as good.
function M.bisect_good() util.git('bisect good') end

-- Mark the current bisect commit as bad.
function M.bisect_bad() util.git('bisect bad') end

-- Skip the current bisect commit.
function M.bisect_skip() util.git('bisect skip') end

-- Reset the current bisect session.
function M.bisect_reset() util.git('bisect reset') end

-- Show the bisect log.
function M.bisect_log() util.git('bisect log') end

-- Open a visualization of the bisect state.
function M.bisect_visualize() util.git('bisect visualize') end

return M
