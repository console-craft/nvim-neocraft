local M = {}

function M.source()
  if vim.bo.filetype ~= 'markdown' then return nil end

  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local col = math.max(0, #vim.api.nvim_get_current_line() - 1)
  local ok, node = pcall(function()
    vim.treesitter.get_parser(0, 'markdown'):parse()
    return vim.treesitter.get_node({ pos = { row, col }, ignore_injections = true })
  end)
  if not ok then return nil end
  while node and node:type() ~= 'fenced_code_block' do
    node = node:parent()
  end
  if not node then return nil end

  local language, content
  for child in node:iter_children() do
    if child:type() == 'info_string' then language = vim.treesitter.get_node_text(child, 0):match('^%s*(%S+)') end
    if child:type() == 'code_fence_content' then content = child end
  end
  if language ~= 'mermaid' then return nil end
  if not content then return '' end

  local lines = vim.split(vim.treesitter.get_node_text(content, 0), '\n', { plain = true })
  local start_row = content:start()
  -- Markdown continuation markers belong to the container, not the diagram.
  for child in content:iter_children() do
    if child:type() == 'block_continuation' then
      local child_row, _, _, end_col = child:range()
      local index = child_row - start_row + 1
      lines[index] = lines[index]:sub(end_col + 1)
    end
  end
  return table.concat(lines, '\n')
end

local function show(source, layout, origin)
  if not vim.api.nvim_win_is_valid(origin) then return end
  if vim.fn.executable('mmdc') ~= 1 then
    vim.notify('Mermaid preview requires mermaid-cli (mmdc) on PATH', vim.log.levels.ERROR)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'neocraft-mermaid'

  local config = { split = layout == 'below' and 'below' or 'right', win = origin }
  if layout == 'float' then
    local width = math.max(1, math.min(math.floor(vim.o.columns * 0.85), vim.o.columns - 4))
    local height = math.max(1, math.min(math.floor(vim.o.lines * 0.8), vim.o.lines - 4))
    config = {
      relative = 'editor',
      width = width,
      height = height,
      col = math.floor((vim.o.columns - width) / 2),
      row = math.floor((vim.o.lines - height) / 2),
      style = 'minimal',
      border = 'rounded',
      title = ' Mermaid · +/- zoom · hjkl pan · = reset · q/Esc close ',
    }
  end
  local win = vim.api.nvim_open_win(buf, true, config)
  for name, value in pairs({
    number = false,
    relativenumber = false,
    signcolumn = 'no',
    colorcolumn = '',
    winbar = '',
    spell = false,
    wrap = false,
    winblend = 0,
  }) do
    vim.api.nvim_set_option_value(name, value, { win = win, scope = 'local' })
  end

  local function text(lines)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
  end
  text({ 'Rendering Mermaid… (q/Esc to close)' })
  for _, key in ipairs({ 'q', '<Esc>' }) do
    vim.keymap.set(
      'n',
      key,
      function() vim.api.nvim_win_close(win, true) end,
      { buffer = buf, silent = true, desc = 'Close Mermaid preview' }
    )
  end

  local path = vim.fn.tempname() .. '.png'
  local process, image, diagram, view_process, view_path, pending_path
  local zoom, pan_x, pan_y, generation = 1, 0, 0, 0
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    once = true,
    callback = function()
      if process then pcall(process.kill, process, 15) end
      if view_process then pcall(view_process.kill, view_process, 15) end
      if image then pcall(image.clear, image) end
      if view_path then vim.fn.delete(view_path) end
      if pending_path then vim.fn.delete(pending_path) end
      vim.fn.delete(path)
    end,
  })

  local function failed(message)
    if image then pcall(image.clear, image) end
    image, diagram = nil, nil
    if view_path then vim.fn.delete(view_path) end
    text(vim.split('Mermaid preview failed (q/Esc to close)\n' .. tostring(message), '\n', { plain = true }))
    vim.fn.delete(path)
  end

  -- shortcut: image.nvim has no render-error callback; replace this timeout when its API exposes one.
  local function check_render(remaining)
    if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) or not image then return end
    if image.is_rendered then return end
    if remaining == 0 then
      failed('image.nvim did not display the PNG. Check ImageMagick and terminal graphics support.')
      return
    end
    if vim.api.nvim_win_get_tabpage(win) == vim.api.nvim_get_current_tabpage() then remaining = remaining - 1 end
    vim.defer_fn(function() check_render(remaining) end, 100)
  end

  local function draw(dx, dy)
    if not diagram then return end
    -- Use the pinned image.nvim terminal geometry so pixel crops match its renderer.
    local cell = require('image/utils/term').get_size()
    if not cell then
      failed('Cannot determine terminal pixel dimensions')
      return
    end
    local columns, rows = vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)
    local scale = math.min(
      columns * cell.cell_width / diagram.image_width,
      rows * cell.cell_height / diagram.image_height
    ) * zoom
    local width = math.max(1, math.floor(diagram.image_width * scale + 0.5))
    local height = math.max(1, math.floor(diagram.image_height * scale + 0.5))
    local view_width = math.min(width, math.floor(columns * cell.cell_width))
    local view_height = math.min(height, math.floor(rows * cell.cell_height))
    pan_x = math.max(0, math.min(pan_x + (dx or 0) * cell.cell_width, width - view_width))
    pan_y = math.max(0, math.min(pan_y + (dy or 0) * cell.cell_height, height - view_height))
    local left, top = math.floor(pan_x / scale), math.floor(pan_y / scale)
    local offset_x = math.floor(pan_x - left * scale + 0.5)
    local offset_y = math.floor(pan_y - top * scale + 0.5)
    local crop_width = math.min(diagram.image_width - left, math.ceil((pan_x + view_width) / scale) - left)
    local crop_height = math.min(diagram.image_height - top, math.ceil((pan_y + view_height) / scale) - top)

    generation = generation + 1
    local current = generation
    if view_process then pcall(view_process.kill, view_process, 15) end
    local output = vim.fn.tempname() .. '.png'
    pending_path = output
    local ok, result = pcall(
      vim.system,
      {
        'magick',
        path,
        '-crop',
        string.format('%dx%d+%d+%d', crop_width, crop_height, left, top),
        '+repage',
        '-resize',
        math.ceil(crop_width * scale) .. 'x',
        '-crop',
        string.format('%dx%d+%d+%d', view_width, view_height, offset_x, offset_y),
        '+repage',
        output,
      },
      { text = true, timeout = 10000 },
      vim.schedule_wrap(function(completed)
        if not vim.api.nvim_buf_is_valid(buf) or current ~= generation then
          vim.fn.delete(output)
          return
        end
        view_process, pending_path = nil, nil
        if completed.code ~= 0 then
          vim.fn.delete(output)
          failed(completed.stderr)
          return
        end
        local rendered, err = pcall(function()
          if image then image:clear() end
          if view_path then vim.fn.delete(view_path) end
          view_path = output
          image = assert(
            require('image').from_file(output, {
              window = win,
              buffer = buf,
              x = 0,
              y = 0,
              width = math.min(columns, math.ceil(view_width / cell.cell_width)),
              height = math.min(rows, math.ceil(view_height / cell.cell_height)),
              max_width_window_percentage = 100,
              max_height_window_percentage = 100,
            }),
            'image.nvim could not load the rendered PNG'
          )
          text({ '' })
          image:render()
          check_render(100)
        end)
        if not rendered then failed(err) end
      end)
    )
    if ok then
      view_process = result
    else
      pending_path = nil
      vim.fn.delete(output)
      failed(result)
    end
  end

  local function map(key, callback, desc)
    vim.keymap.set('n', key, callback, { buffer = buf, silent = true, desc = desc })
  end
  map('+', function()
    zoom = math.min(8, zoom * 1.25)
    draw()
  end, 'Zoom Mermaid in')
  map('-', function()
    zoom = math.max(0.125, zoom / 1.25)
    draw()
  end, 'Zoom Mermaid out')
  map('=', function()
    zoom, pan_x, pan_y = 1, 0, 0
    draw()
  end, 'Reset Mermaid to fit the pane')
  map('h', function() draw(-6 * vim.v.count1, 0) end, 'Pan Mermaid left')
  map('l', function() draw(6 * vim.v.count1, 0) end, 'Pan Mermaid right')
  map('j', function() draw(0, 4 * vim.v.count1) end, 'Pan Mermaid down')
  map('k', function() draw(0, -4 * vim.v.count1) end, 'Pan Mermaid up')

  local ok, result = pcall(
    vim.system,
    {
      'mmdc',
      '-i',
      '-',
      '-o',
      path,
      '-b',
      'transparent',
      '-t',
      vim.o.background == 'dark' and 'dark' or 'default',
      '--scale',
      '4',
    },
    { stdin = source, text = true, timeout = 60000 },
    vim.schedule_wrap(function(completed)
      process = nil
      if not vim.api.nvim_buf_is_valid(buf) then
        vim.fn.delete(path)
        return
      end
      if completed.code ~= 0 then
        failed(completed.stderr ~= '' and completed.stderr or completed.stdout)
        return
      end
      local rendered, err = pcall(function()
        diagram = assert(require('image').from_file(path, {}), 'image.nvim could not load the Mermaid PNG')
        draw()
      end)
      if not rendered then failed(err) end
    end)
  )
  if ok then
    process = result
  else
    failed(result)
  end
end

function M.preview(layout)
  local source = M.source()
  if source == nil then return false end
  local origin = vim.api.nvim_get_current_win()
  -- Expression mappings cannot create windows while textlock is active.
  vim.schedule(function() show(source, layout, origin) end)
  return true
end

return M
