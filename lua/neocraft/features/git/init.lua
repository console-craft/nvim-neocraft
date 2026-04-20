local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

local common = require('neocraft.features.git.common')
local bisect = require('neocraft.features.git.bisect')
local worktrees = require('neocraft.features.git.worktrees')
local cherry_pick = require('neocraft.features.git.cherry_pick')
local rebase = require('neocraft.features.git.rebase')
local branches = require('neocraft.features.git.branches')
local reset = require('neocraft.features.git.reset')
local pending = require('neocraft.features.git.pending')
local hunks = require('neocraft.features.git.hunks')
local diffview = require('neocraft.features.git.diffview')

-- ┌───────────────────────────────────────────┐
-- │ Module exports                            │
-- └───────────────────────────────────────────┘

-- Common Git commands.
M.add_file = common.add_file
M.add_all = common.add_all
M.commit = common.commit
M.commit_amend = common.commit_amend
M.status = common.status
M.open = common.open
M.unstage_all = common.unstage_all
M.unstage_file = common.unstage_file

-- Git bisect commands.
M.bisect_start = bisect.bisect_start
M.bisect_good = bisect.bisect_good
M.bisect_bad = bisect.bisect_bad
M.bisect_skip = bisect.bisect_skip
M.bisect_reset = bisect.bisect_reset
M.bisect_log = bisect.bisect_log
M.bisect_visualize = bisect.bisect_visualize

M.add_worktree = worktrees.add_worktree
M.copy_files_to_worktree = worktrees.copy_files_to_worktree
M.prune_worktrees = worktrees.prune_worktrees
M.remove_worktree = worktrees.remove_worktree
M.yank_worktree_path = worktrees.yank_worktree_path

-- Git cherry-pick commands.
M.cherry_pick = cherry_pick.cherry_pick
M.cherry_pick_continue = cherry_pick.cherry_pick_continue
M.cherry_pick_skip = cherry_pick.cherry_pick_skip
M.cherry_pick_abort = cherry_pick.cherry_pick_abort

-- Git rebase commands.
M.rebase_interactive = rebase.rebase_interactive
M.rebase_continue = rebase.rebase_continue
M.rebase_skip = rebase.rebase_skip
M.rebase_abort = rebase.rebase_abort

-- Git branch removal commands.
M.local_branch_items = branches.local_branch_items
M.remote_branch_items = branches.remote_branch_items
M.delete_local_branch = branches.delete_local_branch
M.delete_remote_branch = branches.delete_remote_branch
M.prune_branches = branches.prune_branches

-- Git commit reset commands.
M.reset_latest_commit_hard = reset.reset_latest_commit_hard
M.reset_latest_commit_mixed = reset.reset_latest_commit_mixed
M.reset_and_clean = reset.reset_and_clean

-- Git pending file navigation commands.
M.next_pending_file = pending.next_pending_file
M.prev_pending_file = pending.prev_pending_file

-- Git hunk navigation and diffs overlay commands.
M.goto_hunk = hunks.goto_hunk
M.toggle_overlay = hunks.toggle_overlay

-- Diffview commands.
M.open_diff = diffview.open_diff
M.open_file_history = diffview.open_file_history
M.open_log = diffview.open_log
M.open_staged_diff = diffview.open_staged_diff
M.open_working_tree_diff = diffview.open_working_tree_diff

return M
