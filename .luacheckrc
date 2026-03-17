std = 'luajit'

-- List of recognized global variables.
globals = { 'Lib' }

-- Don't report unused self arguments of methods.
self = false

-- Report error codes in diagnostics.
codes = true

-- List of error codes to ignore.
ignore = {
  '212', -- Unused argument.
  '631', -- Line is too long.
  '122', -- Indirectly setting a readonly global. (vi.g.foo = ...)
}

-- Global objects defined by runtime.
read_globals = {
  'vim',
}
