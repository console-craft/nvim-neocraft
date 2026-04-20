-- Configure mini.animate.

local M = {}

Lib.later(function()
  local animate = require('mini.animate')
  local normal_scroll_timing = animate.gen_timing.linear({ duration = 110, unit = 'total' })
  local fast_scroll_timing = animate.gen_timing.linear({ duration = 10, unit = 'total' })

  local function adaptive_scroll_timing(step, total_steps)
    if total_steps >= 65 then return fast_scroll_timing(step, total_steps) end
    return normal_scroll_timing(step, total_steps)
  end

  animate.setup({
    cursor = { timing = animate.gen_timing.linear({ duration = 10, unit = 'total' }) },
    scroll = {
      timing = adaptive_scroll_timing,
      subscroll = animate.gen_subscroll.equal({
        predicate = function(total_scroll) return total_scroll > 1 and vim.g.neocraft_mouse_scrolling ~= true end,
      }),
    },
    resize = { enable = false },
    open = { timing = animate.gen_timing.linear({ duration = 10, unit = 'total' }) },
    close = { timing = animate.gen_timing.linear({ duration = 10, unit = 'total' }) },
  })
end)

return M
