-- Shared helpers for Git plugin modules.

---@alias neocraft.git.SystemResult vim.SystemCompleted
---@class neocraft.git.SystemResultFields
---@field code integer
---@field signal? integer
---@field stdout? string
---@field stderr? string

---@class neocraft.git.RunOpts
---@field buf? integer
---@field cwd? string

local M = {}

local root = require('neocraft.core.root')

-- Resolve a buffer handle, defaulting to the current buffer.
---@param buf? integer
---@return integer
function M.resolve_buf(buf)
  if buf == nil or buf == 0 then return vim.api.nvim_get_current_buf() end
  return buf
end

-- Run a `:Git` command through mini.git.
---@param cmd string
function M.git(cmd) vim.cmd('Git ' .. cmd) end

-- Escape a Git argument for Ex command execution.
---@param arg string
---@return string
function M.git_escape(arg) return vim.fn.escape(arg, [[ \]]) end

-- Run a system command synchronously and return its result.
---@param cmd string[]
---@param opts? table
---@return neocraft.git.SystemResult
function M.run_system(cmd, opts) return vim.system(cmd, opts or {}):wait() end

-- Merge stdout and stderr from a Git command result.
---@param result? neocraft.git.SystemResult
---@return string
function M.git_output(result)
  return vim.trim(table.concat(
    vim.tbl_filter(function(part) return part ~= nil and part ~= '' end, {
      result and result.stderr or nil,
      result and result.stdout or nil,
    }),
    '\n'
  ))
end

-- Split text into non-empty trimmed lines.
---@param text? string
---@return string[]
function M.trim_lines(text)
  text = (text or ''):gsub('%s+$', '')
  return text == '' and {} or vim.split(text, '\n', { trimempty = true })
end

-- Resolve the Git repository root for a buffer.
---@param buf? integer
---@return string?
function M.git_root(buf)
  local start_path = root.get({ buf = buf })
  local marker = start_path and vim.fs.find('.git', { path = start_path, upward = true })[1] or nil
  if marker == nil then return nil end

  return root.realpath(vim.fs.dirname(marker)) or vim.fs.normalize(vim.fs.dirname(marker))
end

-- Resolve the Git root or warn when outside a repository.
---@param buf? integer
---@return string?
function M.git_root_or_warn(buf)
  local path = M.git_root(buf)
  if path ~= nil then return path end

  vim.notify('Not inside a Git repository', vim.log.levels.WARN)
  return nil
end

-- Run a Git subprocess from the resolved repository root.
---@param args string[]
---@param opts? neocraft.git.RunOpts
---@return neocraft.git.SystemResult? result
---@return string? repo_root
function M.run_git(args, opts)
  opts = opts or {}

  local repo_root = opts.cwd or M.git_root_or_warn(opts.buf)
  if repo_root == nil then return nil end

  local result = M.run_system(vim.list_extend({ 'git' }, args), {
    cwd = repo_root,
    text = true,
  })

  return result, repo_root
end

-- Notify about a successful Git action, including command output when present.
---@param message string
---@param result? neocraft.git.SystemResult
function M.notify_git_success(message, result)
  local output = M.git_output(result)
  if output ~= '' then
    vim.notify(message .. '\n' .. output, vim.log.levels.INFO)
    return
  end

  vim.notify(message, vim.log.levels.INFO)
end

-- Notify about a failed Git action.
---@param action string
---@param result? neocraft.git.SystemResult
function M.notify_git_failure(action, result)
  local output = M.git_output(result)
  if output == '' then output = 'Git ' .. action .. ' failed' end
  vim.notify(output, vim.log.levels.ERROR)
end

return M
