-- Run with NVIM_APPNAME=nvim-neocraft nvim --headless -u NONE -l scripts/mermaid_test.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.opt.runtimepath:append(vim.fn.stdpath('data') .. '/site')

local loaded, mermaid = pcall(require, 'neocraft.features.mermaid')
assert(loaded, 'Mermaid preview module is missing: ' .. tostring(mermaid))

local function document(lines, row)
  vim.cmd.enew({ bang = true })
  vim.bo.filetype = 'markdown'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { row, 0 })
end

local cases = {
  { lines = { '```mermaid', 'graph TD', 'A-->B', '```' }, row = 2, want = 'graph TD\nA-->B\n' },
  { lines = { '~~~mermaid', 'graph TD', 'A-->B', '~~~' }, row = 3, want = 'graph TD\nA-->B\n' },
  { lines = { '```mermaid', 'graph TD', '```' }, row = 1, want = 'graph TD\n' },
  { lines = { '```mermaid', 'graph TD', '```' }, row = 3, want = 'graph TD\n' },
  { lines = { '```lua', 'print(1)', '```' }, row = 2 },
  { lines = { '```text', '```mermaid', 'graph TD', '```', '```' }, row = 3 },
  { lines = { 'Before', '```mermaid', 'graph TD', '```', 'After' }, row = 5 },
  { lines = { '```mermaid', 'graph TD' }, row = 2, want = 'graph TD\n' },
  { lines = { '> ```mermaid', '> graph TD', '> A-->B', '> ```' }, row = 2, want = 'graph TD\nA-->B\n' },
}

for i, case in ipairs(cases) do
  document(case.lines, case.row)
  assert(mermaid.source() == case.want, 'Wrong Mermaid source in case ' .. i .. ': ' .. vim.inspect(mermaid.source()))
end

vim.bo.filetype = 'lua'
assert(mermaid.source() == nil, 'Non-Markdown buffers must not trigger previews')

print('Mermaid block detection passed')

-- Substitute only terminal geometry and escape writes; the image pipeline is real.
vim.opt.runtimepath:append(vim.fn.stdpath('data') .. '/site/pack/core/opt/image.nvim')
package.loaded['image/utils/term'] = {
  get_size = function()
    return { screen_x = 800, screen_y = 600, screen_cols = 80, screen_rows = 24, cell_width = 10, cell_height = 25 }
  end,
  get_tty = function() return nil end,
}
package.loaded['image/backends/kitty/helpers'] = {
  write_graphics = function() end,
  write_graphics_at = function() end,
  restore_cursor = function() end,
}
local images = require('image')
images.setup({
  integrations = {
    markdown = { enabled = false },
    asciidoc = { enabled = false },
    typst = { enabled = false },
    neorg = { enabled = false },
    syslang = { enabled = false },
  },
})

document({ 'Ordinary Markdown', 'next line' }, 1)
dofile('after/ftplugin/markdown.lua')
local enter = vim.fn.maparg('<CR>', 'n', false, true)
local gf = vim.fn.maparg('gf', 'n', false, true)
local gF = vim.fn.maparg('gF', 'n', false, true)
assert(type(enter.callback) == 'function', 'Markdown must have an Enter preview mapping')
assert(type(gf.callback) == 'function', 'Markdown must have a gf preview mapping')
assert(type(gF.callback) == 'function', 'Markdown must have a gF preview mapping')
assert(enter.callback() == '<CR>', 'Enter must retain its native fallback')
assert(gf.callback() == 'gf', 'gf must retain its native fallback')
assert(gF.callback() == 'gF', 'gF must retain its native fallback')
assert(vim.fn.maparg('<CR>', 'i') == '', 'Insert-mode Enter must not be replaced')
vim.o.winblend = 25

for _, layout in ipairs({ 'float', 'split' }) do
  document({ '```mermaid', 'graph TD', 'A-->B', 'B-->C', 'C-->D', 'D-->E', 'E-->F', '```' }, 2)
  dofile('after/ftplugin/markdown.lua')
  local render_system, source_png = vim.system, nil
  vim.system = function(cmd, opts, callback)
    if cmd[1] == 'mmdc' then source_png = cmd[5] end
    return render_system(cmd, opts, callback)
  end
  local source_win = vim.api.nvim_get_current_win()
  local source_buf = vim.api.nvim_get_current_buf()
  local open_key = layout == 'float' and '<CR>' or 'gf'
  local open_mapping = vim.fn.maparg(open_key, 'n', false, true).callback
  assert(type(open_mapping) == 'function', 'Mermaid mapping must exist')
  vim.api.nvim_feedkeys(vim.keycode(open_key), 'xt', false)
  assert(
    vim.wait(30000, function()
      local current = images.get_images()[1]
      return current ~= nil and current.is_rendered
    end, 20),
    'Preview did not render: ' .. vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false))
  )
  vim.system = render_system
  local source_image = images.from_file(source_png, {})
  assert(
    source_image and source_image.image_width >= 640,
    'Mermaid must produce a high-density source, not enlarge a tiny PNG'
  )
  local image = images.get_images()[1]
  assert(vim.fn.readfile(image.original_path, 'b')[1]:sub(1, 4) == '\137PNG', 'mmdc must produce a PNG')
  assert(image.image_width > 0 and image.image_height > 0, 'ImageMagick must decode the PNG')
  local config = vim.api.nvim_win_get_config(image.window)
  assert((config.relative ~= '') == (layout == 'float'), 'Wrong preview window layout')
  if layout == 'float' then
    assert(vim.wo[image.window].winblend == 0, 'Mermaid popup must be opaque')
    assert(vim.go.winblend == 25, 'Mermaid opacity must not change other popup defaults')
  end
  if layout == 'split' then
    assert(
      vim.api.nvim_win_get_position(image.window)[2] > vim.api.nvim_win_get_position(source_win)[2],
      'Split must open to the right'
    )
  end
  assert(vim.bo[image.buffer].buftype == 'nofile', 'Preview must be a scratch buffer')
  assert(vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)[3] == 'A-->B', 'Preview must not change the source')
  local function assert_fitted()
    local width = vim.api.nvim_win_get_width(image.window) * 10
    local height = vim.api.nvim_win_get_height(image.window) * 25
    assert(
      image.image_width <= width and image.image_height <= height,
      'Initial diagram must fit inside both pane dimensions'
    )
    assert(
      math.abs(image.image_width - image.image_height * source_image.image_width / source_image.image_height) <= 2,
      'Initial fit must show the complete diagram without cropping'
    )
    assert(
      math.min(math.abs(image.image_width - width), math.abs(image.image_height - height)) <= 1,
      'Initial fit must fill its limiting dimension'
    )
  end
  assert_fitted()

  local function signature()
    local result = vim.system({ 'magick', 'identify', '-format', '%#', image.original_path }, { text = true }):wait()
    assert(result.code == 0, result.stderr)
    return result.stdout
  end
  local function press(key)
    local previous_path = image.original_path
    vim.api.nvim_feedkeys(vim.keycode(key), 'xt', false)
    assert(
      vim.wait(15000, function()
        local current = images.get_images()[1]
        if current and current.is_rendered and current.original_path ~= previous_path then
          image = current
          return true
        end
        return false
      end, 20),
      'Viewport did not update for ' .. key
    )
    assert(vim.fn.filereadable(previous_path) == 0, 'Redrawing must remove the previous viewport PNG')
    assert(
      image.rendered_geometry.width <= vim.api.nvim_win_get_width(image.window),
      'Viewport must stay inside its pane'
    )
    return signature()
  end
  local initial = signature()
  assert(press('j') == initial, 'Panning a fitted diagram must clamp at its edge')
  assert(press('k') == initial, 'Panning above the fitted diagram must clamp')
  assert(press('h') == initial, 'Panning left at the edge must clamp')
  local zoomed
  for _ = 1, 8 do
    zoomed = press('+')
  end
  assert(zoomed ~= initial, '+ must enlarge the diagram')
  assert(press('j') ~= zoomed, 'j must reveal lower diagram content when zoomed')
  assert(press('k') == zoomed, 'k must return to the top')
  assert(press('l') ~= zoomed, 'l must reveal content to the right when zoomed')
  assert(press('h') == zoomed, 'h must return to the left')
  for _ = 1, 7 do
    press('-')
  end
  assert(press('-') == initial, '- must reverse zoom steps')
  press('+')
  press('j')
  press('l')
  assert(press('=') == initial, '= must restore automatic fit and the top-left origin')
  vim.api.nvim_feedkeys('++lljj=', 'xt', false)
  assert(press('=') == initial, 'Rapid viewport changes must keep only the latest view')
  vim.api.nvim_win_set_width(image.window, math.max(10, vim.api.nvim_win_get_width(image.window) - 5))
  vim.api.nvim_win_set_height(image.window, math.max(5, vim.api.nvim_win_get_height(image.window) - 3))
  press('=')
  assert_fitted()

  local system, pending, finished = vim.system, nil, false
  vim.system = function(cmd, opts, callback)
    if cmd[1] == 'magick' and callback then
      pending = cmd[#cmd]
      return system(cmd, opts, function(result)
        callback(result)
        vim.schedule(function() finished = true end)
      end)
    end
    return system(cmd, opts, callback)
  end
  vim.api.nvim_feedkeys('+' .. vim.keycode('<Esc>'), 'xt', false)
  assert(not vim.api.nvim_win_is_valid(image.window), 'Esc must close the Mermaid preview')
  assert(vim.wait(10000, function() return finished end, 10), 'Closing must terminate the pending viewport renderer')
  vim.system = system
  assert(pending and vim.fn.filereadable(pending) == 0, 'Closing must remove the pending viewport output')
  assert(#images.get_images() == 0, 'Closing must clear image.nvim graphics and registry')
  assert(vim.fn.filereadable(image.original_path) == 0, 'Closing must remove the temporary PNG')
end
vim.o.winblend = 0

-- A one-pixel corner marker catches losing fractional source pixels at the pan limits.
local real_system, fixture_path = vim.system, nil
vim.system = function(cmd, opts, callback)
  if cmd[1] == 'mmdc' then
    fixture_path = cmd[5]
    return real_system({
      'magick',
      '-size',
      '100x160',
      'xc:black',
      '-channel',
      'R',
      '-fx',
      'i/(w-1)',
      '-channel',
      'G',
      '-fx',
      'j/(h-1)',
      '+channel',
      '-fill',
      'lime',
      '-draw',
      'rectangle 99,0 99,159',
      '-fill',
      'red',
      '-draw',
      'rectangle 0,159 99,159',
      '-fill',
      'white',
      '-draw',
      'point 99,159',
      fixture_path,
    }, { text = true }, callback)
  end
  return real_system(cmd, opts, callback)
end
document({ '```mermaid', 'graph TD', 'A-->B', '```' }, 2)
assert(mermaid.preview('float'))
local function await_image(previous)
  local found
  assert(
    vim.wait(15000, function()
      local current = images.get_images()[1]
      if current and current.is_rendered and current.original_path ~= previous then
        found = current
        return true
      end
      return false
    end, 20),
    'Corner viewport did not render'
  )
  return found
end
local corner = await_image()
vim.system = real_system
vim.api.nvim_win_set_width(corner.window, 25)
vim.api.nvim_feedkeys('++++++++++', 'xt', false)
corner = await_image(corner.original_path)
local function center_color()
  local result = vim
    .system({
      'magick',
      corner.original_path,
      '-format',
      '%[fx:round(255*p{100,200}.r)] %[fx:round(255*p{100,200}.g)]',
      'info:',
    }, { text = true })
    :wait()
  assert(result.code == 0, result.stderr)
  local red, green = result.stdout:match('(%d+)%s+(%d+)')
  return tonumber(red), tonumber(green)
end
local red, green = center_color()
vim.api.nvim_feedkeys('l', 'xt', false)
corner = await_image(corner.original_path)
local moved_red = center_color()
assert(moved_red - red >= 6, 'One horizontal pan must cover at least six terminal columns')
vim.api.nvim_feedkeys('j', 'xt', false)
corner = await_image(corner.original_path)
local _, moved_green = center_color()
assert(moved_green - green >= 6, 'One vertical pan must cover at least four terminal rows')
vim.api.nvim_feedkeys('999l999j', 'xt', false)
corner = await_image(corner.original_path)
local corner_pixel = vim
  .system({ 'magick', corner.original_path, '-format', '%[pixel:p{w-1,h-1}]', 'info:' }, { text = true })
  :wait()
local expected_pixel = vim
  .system({
    'magick',
    fixture_path,
    '-resize',
    '2000x',
    '-gravity',
    'southeast',
    '-crop',
    '250x475+0+0',
    '+repage',
    '-clamp',
    '-depth',
    '8',
    '-format',
    '%[pixel:p{w-1,h-1}]',
    'info:',
  }, { text = true })
  :wait()
assert(corner_pixel.code == 0 and expected_pixel.code == 0, 'Corner pixels must be readable')
assert(
  corner_pixel.stdout == expected_pixel.stdout,
  'Panning must reach the exact source bottom-right corner: '
    .. tostring(corner_pixel.stdout)
    .. ' vs '
    .. tostring(expected_pixel.stdout)
)
vim.api.nvim_feedkeys('q', 'xt', false)

for _, layout in ipairs({ 'float', 'split' }) do
  document({ '```mermaid', 'graph LR', 'A-->B', 'B-->C', 'C-->D', '```' }, 2)
  assert(mermaid.preview(layout))
  local wide = await_image()
  assert(wide.image_width == vim.api.nvim_win_get_width(wide.window) * 10, 'Wide diagrams must fit by width')
  assert(
    wide.image_height < vim.api.nvim_win_get_height(wide.window) * 25,
    'Wide diagrams must not stretch to pane height'
  )
  vim.api.nvim_feedkeys('q', 'xt', false)
end

document({ '```mermaid', 'graph TD', 'A-->B', '```' }, 2)
dofile('after/ftplugin/markdown.lua')
local document_win = vim.api.nvim_get_current_win()
vim.api.nvim_feedkeys('gF', 'xt', false)
local below = await_image()
local document_pos = vim.api.nvim_win_get_position(document_win)
local preview_pos = vim.api.nvim_win_get_position(below.window)
assert(preview_pos[1] > document_pos[1], 'gF must open the diagram below its source document')
assert(preview_pos[2] == document_pos[2], 'gF must create a horizontal, not vertical, split')
assert(
  vim.api.nvim_win_get_width(below.window) == vim.api.nvim_win_get_width(document_win),
  'Horizontal preview must match its source pane width'
)
vim.api.nvim_feedkeys(vim.keycode('<Esc>'), 'xt', false)
assert(not vim.api.nvim_win_is_valid(below.window), 'Esc must close the horizontal preview')
assert(
  #images.get_images() == 0 and vim.fn.filereadable(below.original_path) == 0,
  'Horizontal preview must clean up graphics and its temporary PNG'
)

local width_limit = vim.env.MAGICK_WIDTH_LIMIT
vim.env.MAGICK_WIDTH_LIMIT = '1'
document({ '```mermaid', 'graph TD', 'A-->B', '```' }, 2)
assert(mermaid.preview('float'))
assert(
  vim.wait(
    20000,
    function()
      return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('Mermaid preview failed', 1, true)
        ~= nil
    end,
    20
  ),
  'An asynchronous ImageMagick failure must not leave a blank preview'
)
assert(#images.get_images() == 0, 'Image-render failure must clear the image registry')
vim.api.nvim_feedkeys('q', 'xt', false)
vim.env.MAGICK_WIDTH_LIMIT = width_limit

document({ '```mermaid', 'not a valid diagram', '```' }, 2)
assert(mermaid.preview('float'), 'Invalid diagrams still belong to Mermaid')
assert(
  vim.wait(
    30000,
    function()
      return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('Mermaid preview failed', 1, true)
        ~= nil
    end,
    20
  ),
  'mmdc errors must be visible in the preview'
)
vim.api.nvim_feedkeys('q', 'xt', false)

-- Keep the real subprocess while observing its completion for the early-close race.
local system = vim.system
local finished, output
vim.system = function(cmd, opts, callback)
  for i, arg in ipairs(cmd) do
    if arg == '-o' then output = cmd[i + 1] end
  end
  return system(cmd, opts, function(result)
    callback(result)
    vim.schedule(function() finished = true end)
  end)
end
document({ '```mermaid', 'graph TD', 'A-->B', '```' }, 2)
local source_win = vim.api.nvim_get_current_win()
assert(mermaid.preview('float'))
assert(vim.wait(1000, function() return output ~= nil end, 10), 'Renderer must start')
vim.api.nvim_feedkeys('q', 'xt', false)
assert(vim.wait(10000, function() return finished end, 10), 'Closed preview renderer must terminate')
assert(vim.api.nvim_get_current_win() == source_win, 'A closed preview must not reopen on completion')
assert(vim.fn.filereadable(output) == 0, 'Early close must not leak a PNG')
vim.system = system

local path, notify = vim.env.PATH, vim.notify
local notice
vim.env.PATH = ''
vim.notify = function(message) notice = message end
local windows = #vim.api.nvim_list_wins()
assert(mermaid.preview('float'))
assert(vim.wait(1000, function() return notice ~= nil end, 10), 'Missing mmdc must report an error')
assert(notice:find('mmdc', 1, true), 'Missing dependency error must name mmdc')
assert(#vim.api.nvim_list_wins() == windows, 'Missing mmdc must not leave a preview window')
vim.env.PATH, vim.notify = path, notify

print('Mermaid previews, key fallbacks, errors, and cleanup passed')
