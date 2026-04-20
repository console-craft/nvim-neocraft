-- Configure mini.hipatterns keyword and CSS color highlighting.

local M = {}

-- ┌───────────────────────────────────────────┐
-- │ Module helpers                            │
-- └───────────────────────────────────────────┘

-- Trim leading and trailing whitespace from a string.
local function trim(value) return (value:gsub('^%s+', ''):gsub('%s+$', '')) end

-- Split a string by commas, trimming whitespace from each part.
local function split_commas(value)
  local parts = {}

  for part in value:gmatch('[^,]+') do
    parts[#parts + 1] = trim(part)
  end

  return parts
end

-- Split a string by whitespace, treating consecutive whitespace as a single separator.
local function split_spaces(value)
  local parts = {}

  for part in value:gmatch('%S+') do
    parts[#parts + 1] = part
  end

  return parts
end

-- Parse an alpha value from a CSS color function, accepting a number between 0 and 1 or a percent between 0% and 100%.
local function parse_alpha(value)
  if value == nil or value == '' then return true end

  if vim.endswith(value, '%') then
    local percent = tonumber(value:sub(1, -2))
    return percent ~= nil and percent >= 0 and percent <= 100
  end

  local alpha = tonumber(value)
  return alpha ~= nil and alpha >= 0 and alpha <= 1
end

-- Parse a RGB value from a CSS color function, accepting a number between 0 and 255 or a percent between 0% and 100%.
local function parse_rgb_channel(value)
  if vim.endswith(value, '%') then
    local percent = tonumber(value:sub(1, -2))
    if percent == nil or percent < 0 or percent > 100 then return nil end

    return math.floor((255 * percent / 100) + 0.5)
  end

  local channel = tonumber(value)
  if channel == nil or channel < 0 or channel > 255 then return nil end

  return math.floor(channel + 0.5)
end

-- Parse a hue value from a CSS color function, accepting a number between 0 and 360 with an optional 'deg' suffix.
local function parse_hue(value)
  local hue = value
  if vim.endswith(hue, 'deg') then hue = hue:sub(1, -4) end

  hue = tonumber(hue)
  if hue == nil then return nil end

  return (hue % 360) / 360
end

-- Parse a percentage value from a CSS color function, accepting a percent between 0% and 100% with a '%' suffix.
local function parse_percentage(value)
  if not vim.endswith(value, '%') then return nil end

  local percent = tonumber(value:sub(1, -2))
  if percent == nil or percent < 0 or percent > 100 then return nil end

  return percent / 100
end

-- Convert an HSL hue value to RGB.
local function hue_to_rgb(min_channel, max_channel, hue_pos)
  if hue_pos < 0 then hue_pos = hue_pos + 1 end
  if hue_pos > 1 then hue_pos = hue_pos - 1 end
  if hue_pos < 1 / 6 then return min_channel + ((max_channel - min_channel) * 6 * hue_pos) end
  if hue_pos < 1 / 2 then return max_channel end
  if hue_pos < 2 / 3 then return min_channel + ((max_channel - min_channel) * ((2 / 3) - hue_pos) * 6) end
  return min_channel
end

-- Convert HSL color components to a hexadecimal RGB string.
local function hsl_to_hex(h, s, l)
  if s == 0 then
    local channel = math.floor((l * 255) + 0.5)
    return string.format('#%02x%02x%02x', channel, channel, channel)
  end

  local q = l < 0.5 and (l * (1 + s)) or (l + s - (l * s))
  local p = 2 * l - q

  local r = math.floor((255 * hue_to_rgb(p, q, h + (1 / 3))) + 0.5)
  local g = math.floor((255 * hue_to_rgb(p, q, h)) + 0.5)
  local b = math.floor((255 * hue_to_rgb(p, q, h - (1 / 3))) + 0.5)

  return string.format('#%02x%02x%02x', r, g, b)
end

-- Extract the body of a CSS function from a match string.
local function parse_css_body(match, names)
  local body
  for _, name in ipairs(names) do
    body = match:match('^' .. name .. '%((.*)%)$')
    if body ~= nil then break end
  end

  return body and trim(body) or nil
end

-- Parse the components of a CSS function body, splitting by commas or spaces and handling an optional alpha component.
local function parse_function_parts(body)
  if body:find(',', 1, true) then return split_commas(body) end

  local components, alpha = body:match('^(.-)%s*/%s*(.-)$')
  local parts = split_spaces(components or body)
  if alpha ~= nil then parts[#parts + 1] = trim(alpha) end

  return parts
end

-- ┌───────────────────────────────────────────┐
-- │ Setup Mini Hipatterns                     │
-- └───────────────────────────────────────────┘

Lib.later(function()
  local hipatterns = require('mini.hipatterns')

  -- Parse common CSS color functions and compute a highlight group with the corresponding background color.
  local function css_function_color_group(_, match)
    local rgb_body = parse_css_body(match, { 'rgb', 'rgba' })
    if rgb_body ~= nil then
      local parts = parse_function_parts(rgb_body)
      if #parts ~= 3 and #parts ~= 4 then return nil end
      if not parse_alpha(parts[4]) then return nil end

      local r = parse_rgb_channel(parts[1])
      local g = parse_rgb_channel(parts[2])
      local b = parse_rgb_channel(parts[3])
      if r == nil or g == nil or b == nil then return nil end

      local hex = string.format('#%02x%02x%02x', r, g, b)
      return hipatterns.compute_hex_color_group(hex, 'bg')
    end

    local hsl_body = parse_css_body(match, { 'hsl', 'hsla' })
    if hsl_body == nil then return nil end

    local parts = parse_function_parts(hsl_body)
    if #parts ~= 3 and #parts ~= 4 then return nil end
    if not parse_alpha(parts[4]) then return nil end

    local h = parse_hue(parts[1])
    local s = parse_percentage(parts[2])
    local l = parse_percentage(parts[3])
    if h == nil or s == nil or l == nil then return nil end

    return hipatterns.compute_hex_color_group(hsl_to_hex(h, s, l), 'bg')
  end

  hipatterns.setup({
    highlighters = {
      error = { pattern = '%f[%w]()ERROR()%f[%W]', group = 'MiniHipatternsFixme' },
      danger = { pattern = '%f[%w]()DANGER()%f[%W]', group = 'MiniHipatternsFixme' },
      critical = { pattern = '%f[%w]()CRITICAL()%f[%W]', group = 'MiniHipatternsFixme' },
      fail = { pattern = '%f[%w]()FAIL()%f[%W]', group = 'MiniHipatternsFixme' },
      bug = { pattern = '%f[%w]()BUG()%f[%W]', group = 'MiniHipatternsFixme' },
      fixme = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' },
      warning = { pattern = '%f[%w]()WARNING()%f[%W]', group = 'MiniHipatternsHack' },
      caution = { pattern = '%f[%w]()CAUTION()%f[%W]', group = 'MiniHipatternsHack' },
      important = { pattern = '%f[%w]()IMPORTANT()%f[%W]', group = 'MiniHipatternsHack' },
      warn = { pattern = '%f[%w]()WARN()%f[%W]', group = 'MiniHipatternsHack' },
      deprecated = { pattern = '%f[%w]()DEPRECATED()%f[%W]', group = 'MiniHipatternsHack' },
      wip = { pattern = '%f[%w]()WIP()%f[%W]', group = 'MiniHipatternsHack' },
      temp = { pattern = '%f[%w]()TEMP()%f[%W]', group = 'MiniHipatternsTodo' },
      temporary = { pattern = '%f[%w]()TEMPORARY()%f[%W]', group = 'MiniHipatternsTodo' },
      todo = { pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsTodo' },
      skip = { pattern = '%f[%w]()SKIP()%f[%W]', group = 'MiniHipatternsTodo' },
      patch = { pattern = '%f[%w]()PATCH()%f[%W]', group = 'MiniHipatternsTodo' },
      xxx = { pattern = '%f[%w]()XXX()%f[%W]', group = 'MiniHipatternsTodo' },
      success = { pattern = '%f[%w]()SUCCESS()%f[%W]', group = 'MiniHipatternsOK' },
      completed = { pattern = '%f[%w]()COMPLETED()%f[%W]', group = 'MiniHipatternsOK' },
      done = { pattern = '%f[%w]()DONE()%f[%W]', group = 'MiniHipatternsOK' },
      ok = { pattern = '%f[%w]()OK()%f[%W]', group = 'MiniHipatternsOK' },
      fixes = { pattern = '%f[%w]()FIXES()%f[%W]', group = 'MiniHipatternsOK' },
      fix = { pattern = '%f[%w]()FIX()%f[%W]', group = 'MiniHipatternsOK' },
      info = { pattern = '%f[%w]()INFO()%f[%W]', group = 'MiniHipatternsNote' },
      hint = { pattern = '%f[%w]()HINT()%f[%W]', group = 'MiniHipatternsNote' },
      note = { pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote' },
      tip = { pattern = '%f[%w]()TIP()%f[%W]', group = 'MiniHipatternsNote' },
      example = { pattern = '%f[%w]()EXAMPLE()%f[%W]', group = 'MiniHipatternsNote' },
      docs = { pattern = '%f[%w]()DOCS()%f[%W]', group = 'MiniHipatternsNote' },
      hex_color = hipatterns.gen_highlighter.hex_color(),
      rgb_color = {
        pattern = {
          '()%f[%a]rgb%b()()',
          '()%f[%a]rgba%b()()',
        },
        group = css_function_color_group,
      },
      hsl_color = {
        pattern = {
          '()%f[%a]hsl%b()()',
          '()%f[%a]hsla%b()()',
        },
        group = css_function_color_group,
      },
    },
  })
end)

return M
