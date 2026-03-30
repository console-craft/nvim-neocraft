local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Helpers                                   │
-- └───────────────────────────────────────────┘

local root = require('neocraft.core.root')
local function resolve_buf(buf) return (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf end
local function git(cmd) vim.cmd('Git ' .. cmd) end
local function git_escape(arg) return vim.fn.escape(arg, [[ \]]) end

-- ┌───────────────────────────────────────────┐
-- │ Common git operations                     │
-- └───────────────────────────────────────────┘

local function notify_missing_file(action) vim.notify('No file context for Git ' .. action, vim.log.levels.WARN) end

local function has_file_context(buf)
  buf = resolve_buf(buf)

  return vim.bo[buf].buftype == '' and vim.api.nvim_buf_get_name(buf) ~= ''
end

local function save_buffer(buf)
  buf = resolve_buf(buf)

  return vim.api.nvim_buf_call(buf, function() return pcall(vim.cmd, 'silent update') end)
end

function M.add_file()
  if not has_file_context() then
    notify_missing_file('add')
    return
  end

  local ok = save_buffer(0)
  if not ok then return end

  git('add -- %')
end

local function unsaved_file_buffers()
  local result = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_valid(buf)
      and vim.bo[buf].buftype == ''
      and vim.api.nvim_buf_get_name(buf) ~= ''
      and vim.bo[buf].modified
    then
      table.insert(result, buf)
    end
  end

  return result
end

function M.add_all()
  local unsaved = unsaved_file_buffers()
  if #unsaved > 0 then
    local message = ('You have unsaved changes in %d buffer%s. Stage only saved changes?'):format(
      #unsaved,
      #unsaved == 1 and '' or 's'
    )
    local choice = vim.fn.confirm(message, '&Yes\n&No', 2)
    if choice ~= 1 then return end
  end

  git('add -A')
end

function M.blame()
  if not has_file_context() then
    notify_missing_file('blame')
    return
  end

  git('blame -- %')
end

function M.commit() git('commit') end

function M.commit_amend() git('commit --amend') end

function M.diff() git('diff') end

function M.diff_staged() git('diff --cached') end

function M.log_repo() git('log --oneline --topo-order') end

function M.log_buffer()
  if not has_file_context() then
    notify_missing_file('log')
    return
  end

  git('log -p --follow -- %')
end

function M.status() git('status') end

-- Open contextual git-related data based on file type and what is currently selected or under the cursor:
-- * normal file: show line diff history
-- * diff patch:  show state of file belonging to the version under cursor
-- * commit hash: show the commit associated to that hash
function M.open() require('mini.git').show_at_cursor({ split = 'auto' }) end

-- ┌───────────────────────────────────────────┐
-- │ Git "Bisect" operations group             │
-- └───────────────────────────────────────────┘

local function prompt_commit(prompt, callback)
  vim.ui.input({ prompt = prompt }, function(input)
    if input == nil then return end

    local commit = vim.trim(input)
    if commit == '' then return end

    callback(commit)
  end)
end

function M.bisect_start()
  prompt_commit('Bisect bad commit:', function(bad)
    prompt_commit(
      'Bisect good commit:',
      function(good) git('bisect start ' .. git_escape(bad) .. ' ' .. git_escape(good)) end
    )
  end)
end

function M.bisect_good() git('bisect good') end

function M.bisect_bad() git('bisect bad') end

function M.bisect_skip() git('bisect skip') end

function M.bisect_reset() git('bisect reset') end

function M.bisect_log() git('bisect log') end

function M.bisect_visualize() git('bisect visualize') end

-- ┌───────────────────────────────────────────┐
-- │ Git "Cherry-pick" operations group        │
-- └───────────────────────────────────────────┘

local function split_git_args(input) return vim.tbl_map(git_escape, vim.split(input, '%s+', { trimempty = true })) end

function M.cherry_pick()
  vim.ui.input({
    prompt = 'Cherry-pick commit sha(s):',
  }, function(input)
    if input == nil then return end

    local commits = split_git_args(vim.trim(input))
    if #commits == 0 then return end

    git('cherry-pick ' .. table.concat(commits, ' '))
  end)
end

function M.cherry_pick_continue() git('cherry-pick --continue') end

function M.cherry_pick_skip() git('cherry-pick --skip') end

function M.cherry_pick_abort() git('cherry-pick --abort') end

-- ┌───────────────────────────────────────────┐
-- │ Git "Rebase" operations group             │
-- └───────────────────────────────────────────┘

function M.rebase_interactive()
  vim.ui.input({
    prompt = 'Rebase starting poin (use "root" to include first commit):',
  }, function(input)
    if input == nil then return end

    local start = vim.trim(input)
    if start == '' then return end

    if start == 'root' then
      git('rebase -i --root')
      return
    end

    git('rebase -i ' .. git_escape(start))
  end)
end

function M.rebase_continue() git('rebase --continue') end

function M.rebase_skip() git('rebase --skip') end

function M.rebase_abort() git('rebase --abort') end

-- ┌───────────────────────────────────────────┐
-- │ Git "Remove" operations group             │
-- └───────────────────────────────────────────┘

local function branch_item_text(name, sha, subject, extra)
  local suffix = extra and extra ~= '' and (' [' .. extra .. ']') or ''
  return string.format('%-24s %-10s %s%s', name, sha or '-', subject or '', suffix)
end

local function run_system(cmd, opts)
  local proc = vim.system(cmd, opts or {})
  local result = proc:wait()

  if type(result) == 'table' then return result end

  return {
    code = result,
    signal = proc.signal or 0,
    stdout = proc.stdout or '',
    stderr = proc.stderr or '',
  }
end

local function checked_out_branches(repo_root)
  local result = run_system({ 'git', 'worktree', 'list', '--porcelain' }, {
    cwd = repo_root,
    text = true,
  })
  if result.code ~= 0 then return {} end

  local branches = {}
  for _, line in ipairs(vim.split(result.stdout or '', '\n', { plain = true })) do
    local branch = line:match('^branch refs/heads/(.+)$')
    if branch then branches[branch] = true end
  end

  return branches
end

local function git_output(result)
  return vim.trim(table.concat(
    vim.tbl_filter(function(part) return part ~= nil and part ~= '' end, {
      result and result.stderr or nil,
      result and result.stdout or nil,
    }),
    '\n'
  ))
end

local function trim_lines(text)
  text = (text or ''):gsub('%s+$', '')
  return text == '' and {} or vim.split(text, '\n', { trimempty = true })
end

local function git_root(buf)
  local start_path = root.get({ buf = buf })
  local marker = start_path and vim.fs.find('.git', { path = start_path, upward = true })[1] or nil
  if marker == nil then return nil end

  return root.realpath(vim.fs.dirname(marker)) or vim.fs.normalize(vim.fs.dirname(marker))
end

local function git_root_or_warn(buf)
  local path = git_root(buf)
  if path ~= nil then return path end

  vim.notify('Not inside a Git repository', vim.log.levels.WARN)
  return nil
end

function M.local_branch_items()
  local repo_root = git_root_or_warn()
  if repo_root == nil then return nil, 'Not inside a Git repository' end

  local current_result = run_system({ 'git', 'branch', '--show-current' }, {
    cwd = repo_root,
    text = true,
  })
  local current_branch = trim_lines(current_result.stdout)[1]
  local checked_out = checked_out_branches(repo_root)

  local result = run_system({
    'git',
    'for-each-ref',
    '--format=%(refname:short)\t%(objectname:short)\t%(subject)',
    'refs/heads',
  }, {
    cwd = repo_root,
    text = true,
  })
  if result.code ~= 0 then return nil, git_output(result) end

  local items = {}
  for _, line in ipairs(trim_lines(result.stdout)) do
    local parts = vim.split(line, '\t', { plain = true })
    local name, sha, subject = unpack(parts)

    if name ~= nil and name ~= current_branch and not checked_out[name] then
      table.insert(items, {
        branch = name,
        sha = sha,
        subject = subject or '',
        text = branch_item_text(name, sha, subject),
      })
    end
  end

  table.sort(items, function(a, b) return a.branch < b.branch end)
  return items, repo_root
end

function M.remote_branch_items()
  local repo_root = git_root_or_warn()
  if repo_root == nil then return nil, 'Not inside a Git repository' end

  local result = run_system({
    'git',
    'for-each-ref',
    '--format=%(refname:short)\t%(objectname:short)\t%(subject)',
    'refs/remotes/origin',
  }, {
    cwd = repo_root,
    text = true,
  })
  if result.code ~= 0 then return nil, git_output(result) end

  local items = {}
  for _, line in ipairs(trim_lines(result.stdout)) do
    local parts = vim.split(line, '\t', { plain = true })
    local ref, sha, subject = unpack(parts)

    if ref ~= nil and ref ~= 'origin/HEAD' then
      local branch = ref:gsub('^origin/', '')
      table.insert(items, {
        branch = branch,
        ref = ref,
        sha = sha,
        subject = subject or '',
        text = branch_item_text(branch, sha, subject),
      })
    end
  end

  table.sort(items, function(a, b) return a.branch < b.branch end)
  return items, repo_root
end

local function notify_git_success(message, result)
  local output = git_output(result)
  if output ~= '' then
    vim.notify(message .. '\n' .. output, vim.log.levels.INFO)
    return
  end

  vim.notify(message, vim.log.levels.INFO)
end

local function notify_git_failure(action, result)
  local output = git_output(result)
  if output == '' then output = 'Git ' .. action .. ' failed' end
  vim.notify(output, vim.log.levels.ERROR)
end

local function run_git(args, opts)
  opts = opts or {}

  local repo_root = opts.cwd or git_root_or_warn(opts.buf)
  if repo_root == nil then return nil end

  local result = run_system(vim.list_extend({ 'git' }, args), {
    cwd = repo_root,
    text = true,
  })

  return result, repo_root
end

function M.delete_local_branch_prompt()
  require('neocraft.pickers').git_local_branches(function(item)
    local message = ('Delete local branch %s?\n%s'):format(
      item.branch,
      item.sha and (item.sha .. ' ' .. item.subject) or ''
    )
    local choice = vim.fn.confirm(message, '&Yes\n&No', 2)
    if choice ~= 1 then return end

    local result = run_git({ 'branch', '-D', item.branch })
    if result == nil then return end
    if result.code ~= 0 then
      notify_git_failure('delete local branch', result)
      return
    end

    notify_git_success('Deleted local branch ' .. item.branch, result)
  end)
end

function M.delete_remote_branch_prompt()
  require('neocraft.pickers').git_remote_branches(function(item)
    local message = ('Delete remote branch origin/%s?\n%s'):format(
      item.branch,
      item.sha and (item.sha .. ' ' .. item.subject) or ''
    )
    local choice = vim.fn.confirm(message, '&Yes\n&No', 2)
    if choice ~= 1 then return end

    local result = run_git({ 'push', 'origin', '--delete', item.branch })
    if result == nil then return end
    if result.code ~= 0 then
      notify_git_failure('delete remote branch', result)
      return
    end

    notify_git_success('Deleted remote branch origin/' .. item.branch, result)
  end)
end

local function notify_modified_buffers(action)
  vim.notify('Save or discard modified buffers before ' .. action, vim.log.levels.WARN)
end

local function has_unsaved_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then return true end
  end

  return false
end

local function current_head_summary(repo_root)
  local result = run_system({ 'git', 'log', '-1', '--format=%h %s' }, {
    cwd = repo_root,
    text = true,
  })
  if result.code ~= 0 then return 'HEAD' end

  return trim_lines(result.stdout)[1] or 'HEAD'
end

function M.reset_latest_commit_hard()
  if has_unsaved_buffers() then
    notify_modified_buffers('running git reset --hard HEAD~1')
    return
  end

  local repo_root = git_root_or_warn()
  if repo_root == nil then return end

  local head = current_head_summary(repo_root)
  local choice =
    vim.fn.confirm(('Discard latest commit and tracked changes from disk?\n%s'):format(head), '&Yes\n&No', 2)
  if choice ~= 1 then return end

  local result = run_git({ 'reset', '--hard', 'HEAD~1' }, { cwd = repo_root })
  if result == nil then return end
  if result.code ~= 0 then
    notify_git_failure('reset --hard HEAD~1', result)
    return
  end

  notify_git_success('Discarded latest commit and tracked changes', result)
end

function M.reset_latest_commit_mixed()
  local repo_root = git_root_or_warn()
  if repo_root == nil then return end

  local head = current_head_summary(repo_root)
  local choice = vim.fn.confirm(('Remove latest commit and keep changes unstaged?\n%s'):format(head), '&Yes\n&No', 2)
  if choice ~= 1 then return end

  local result = run_git({ 'reset', '--mixed', 'HEAD~1' }, { cwd = repo_root })
  if result == nil then return end
  if result.code ~= 0 then
    notify_git_failure('reset --mixed HEAD~1', result)
    return
  end

  notify_git_success('Removed latest commit and kept changes unstaged', result)
end

function M.prune_branches()
  local choice = vim.fn.confirm('Prune stale remote branches with git fetch --prune?', '&Yes\n&No', 2)
  if choice ~= 1 then return end

  local result = run_git({ 'fetch', '--prune' })
  if result == nil then return end
  if result.code ~= 0 then
    notify_git_failure('fetch --prune', result)
    return
  end

  notify_git_success('Pruned stale remote branches', result)
end

function M.reset_and_clean()
  if has_unsaved_buffers() then
    notify_modified_buffers('running git reset --hard && git clean -fd')
    return
  end

  local repo_root = git_root_or_warn()
  if repo_root == nil then return end

  local choice = vim.fn.confirm(
    'Discard tracked changes and delete untracked files/directories from disk?\nThis cannot be undone.',
    '&Yes\n&No',
    2
  )
  if choice ~= 1 then return end

  local reset_result = run_git({ 'reset', '--hard' }, { cwd = repo_root })
  if reset_result == nil then return end
  if reset_result.code ~= 0 then
    notify_git_failure('reset --hard', reset_result)
    return
  end

  local clean_result = run_git({ 'clean', '-fd' }, { cwd = repo_root })
  if clean_result == nil then return end
  if clean_result.code ~= 0 then
    notify_git_failure('clean -fd', clean_result)
    return
  end

  local output = table.concat(
    vim.tbl_filter(function(part) return part ~= '' end, {
      git_output(reset_result),
      git_output(clean_result),
    }),
    '\n'
  )
  if output ~= '' then
    vim.notify('Reset tracked changes and cleaned untracked files\n' .. output, vim.log.levels.INFO)
    return
  end

  vim.notify('Reset tracked changes and cleaned untracked files', vim.log.levels.INFO)
end

-- ┌───────────────────────────────────────────┐
-- │ Git pending files navigation and counts   │
-- └───────────────────────────────────────────┘

local function rel_to_root(path, git_root_path) return vim.fs.relpath(git_root_path, path) or vim.fs.basename(path) end

local function open_file(path) vim.cmd('edit ' .. vim.fn.fnameescape(path)) end

local function index_of(list, value)
  for i, item in ipairs(list) do
    if item == value then return i end
  end
end

local function pending_files(repo_root, staged)
  local result = run_system({ 'git', 'status', '--porcelain=v1', '-z', '--untracked-files=all' }, {
    cwd = repo_root,
    text = true,
  })
  if result.code ~= 0 then return {}, {} end

  local tokens = {}
  for token in (result.stdout or ''):gmatch('([^%z]+)') do
    table.insert(tokens, token)
  end

  local files = {}
  local seen = {}
  local is_new = {}
  local i = 1

  while i <= #tokens do
    local head = tokens[i]
    local xy = head:sub(1, 2)
    local x = xy:sub(1, 1)
    local y = xy:sub(2, 2)
    local path = head:sub(4)

    if x == 'R' or x == 'C' then
      i = i + 1
      path = tokens[i]
    end

    local include
    if staged then
      include = x ~= ' ' and x ~= 'D' and xy ~= '??'
    else
      include = xy == '??' or y ~= ' '
      if y == 'D' then include = false end
    end

    if include and path and path ~= '' then
      local absolute_path = vim.fs.normalize(vim.fs.joinpath(repo_root, path))
      local stat = vim.uv.fs_stat(absolute_path)

      if stat and stat.type == 'file' and not seen[absolute_path] then
        seen[absolute_path] = true
        if not staged and xy == '??' then is_new[absolute_path] = true end
        table.insert(files, absolute_path)
      end
    end

    i = i + 1
  end

  table.sort(files, function(a, b) return a:lower() < b:lower() end)

  return files, is_new
end

local function jump_pending_file(delta, staged)
  local repo_root = git_root_or_warn(0)
  if repo_root == nil then return end

  local files, is_new = pending_files(repo_root, staged)
  if #files == 0 then
    local message = staged and 'No staged files' or 'No untracked or unstaged files'
    vim.notify(message, vim.log.levels.INFO)
    return
  end

  local current_path = root.bufpath(0)
  local idx = current_path and index_of(files, current_path) or nil
  local target = idx == nil and (delta > 0 and 1 or #files) or ((idx - 1 + delta) % #files) + 1
  local path = files[target]

  open_file(path)

  local tag = staged and '(STAGED)' or (is_new[path] and '(NEW)' or '(CHANGED)')
  local message = ('(%d/%d) %s %s'):format(target, #files, rel_to_root(path, repo_root), tag)
  vim.api.nvim_echo({ { message, 'Normal' } }, false, {})
end

function M.next_pending_file(staged) jump_pending_file(1, staged) end

function M.prev_pending_file(staged) jump_pending_file(-1, staged) end

-- ┌───────────────────────────────────────────┐
-- │ Git hunk navigation and counts            │
-- └───────────────────────────────────────────┘

local function current_range_idx(ranges, line)
  for i, range in ipairs(ranges) do
    if line >= range.start and line <= range.finish then return i end
  end

  for i, range in ipairs(ranges) do
    if line < range.start then return i end
  end

  return #ranges
end

local function hunk_buf_end(hunk)
  local start = math.max(tonumber(hunk.buf_start) or 1, 1)
  local count = tonumber(hunk.buf_count) or 0
  if count <= 0 then return start end

  return math.max(start + count - 1, 1)
end

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

local inline_hunk_count_group = Lib.augroup('git_hunk_count')

local inline_hunk_count_ns = vim.api.nvim_create_namespace('neocraft_git_hunk_count')

local function clear_inline_hunk_count(buf)
  buf = resolve_buf(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end

  vim.api.nvim_buf_clear_namespace(buf, inline_hunk_count_ns, 0, -1)
end

local function show_inline_hunk_count(buf)
  buf = resolve_buf(buf)
  clear_inline_hunk_count(buf)

  local mini_diff = require('mini.diff')
  local data = mini_diff.get_buf_data(buf)
  if data == nil or data.hunks == nil or #data.hunks == 0 then return end

  local ranges = get_hunk_ranges(data.hunks)
  if #ranges == 0 then return end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  local idx = current_range_idx(ranges, line)
  local text = ('  %d/%d'):format(idx, #ranges)

  vim.api.nvim_buf_set_extmark(buf, inline_hunk_count_ns, line - 1, 0, {
    virt_text = { { text, 'NeocraftMiniDiffCount' } },
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

function M.goto_hunk(direction)
  local mini_diff = require('mini.diff')

  mini_diff.goto_hunk(direction, { n_times = vim.v.count1 })
  vim.cmd('normal! zz')

  local buf = vim.api.nvim_get_current_buf()
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_get_current_buf() ~= buf then return end
    show_inline_hunk_count(buf)
  end)
end

function M.toggle_overlay() require('mini.diff').toggle_overlay(0) end

-- ┌───────────────────────────────────────────┐
-- │ Setup                                     │
-- └───────────────────────────────────────────┘

-- mini.clue wiring

Lib.autocmd('User', {
  group = Lib.augroup('git'),
  pattern = 'MiniGitCommandSplit',
  desc = 'Ensure mini.clue triggers in Git output buffers',
  callback = function(args)
    local data = args.data or {}
    local win = data.win_stdout
    if type(win) ~= 'number' or not vim.api.nvim_win_is_valid(win) then return end

    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(win) then return end

      local ok, clue = pcall(require, 'mini.clue')
      if not ok then return end

      clue.ensure_buf_triggers(vim.api.nvim_win_get_buf(win))
    end)
  end,
})

-- mini.diff setup

Lib.later(function()
  vim.api.nvim_set_hl(0, 'NeocraftMiniDiffCount', { default = true, link = 'MiniDiffSignChange' })

  require('mini.diff').setup({
    mappings = {
      goto_first = '',
      goto_prev = '',
      goto_next = '',
      goto_last = '',
    },
    view = {
      style = 'sign',
      signs = {
        add = '▎',
        change = '▎',
        delete = '▎',
      },
    },
    options = {
      wrap_goto = true,
      algorithm = 'patience',
      indent_heuristic = false,
      linematch = 0,
    },
  })
end)

-- mini.git setup

Lib.later(function() require('mini.git').setup() end)

return M
