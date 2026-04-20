local M = {}

local map = function(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { silent = true, desc = desc }) end

local function move(method, ...)
  local ok, textobjects = pcall(require, 'nvim-treesitter-textobjects.move')
  if ok then textobjects[method](...) end
end

map(']f', function() move('goto_next_start', '@function.outer') end, 'Next function start')
map(']F', function() move('goto_next_end', '@function.outer') end, 'Next function end')
map('[f', function() move('goto_previous_start', '@function.outer') end, 'Prev function start')
map('[F', function() move('goto_previous_end', '@function.outer') end, 'Prev function end')
map(']c', function() move('goto_next_start', '@class.outer') end, 'Next class start')
map(']C', function() move('goto_next_end', '@class.outer') end, 'Next class end')
map('[c', function() move('goto_previous_start', '@class.outer') end, 'Prev class start')
map('[C', function() move('goto_previous_end', '@class.outer') end, 'Prev class end')
map(']z', function() move('goto_next_start', '@fold', 'folds') end, 'Next fold')
map('[z', function() move('goto_previous_start', '@fold', 'folds') end, 'Prev fold')

function M.select_parent_node() require('vim.treesitter._select').select_parent(vim.v.count1) end

function M.select_child_node() require('vim.treesitter._select').select_child(vim.v.count1) end

return M
