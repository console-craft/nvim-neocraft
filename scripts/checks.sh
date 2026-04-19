#!/usr/bin/env bash

set -euo pipefail

# Repo verification entrypoint for Neocraft maintainers and agent-driven
# verification. This intentionally runs Stylua in write mode before the
# diagnostic-only checks so later passes see normalized Lua formatting.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

export XDG_CONFIG_HOME="$(dirname -- "$ROOT_DIR")"
export NVIM_APPNAME="$(basename -- "$ROOT_DIR")"

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
MASON_BIN_DIR="$XDG_DATA_HOME/$NVIM_APPNAME/mason/bin"

if [[ -d "$MASON_BIN_DIR" ]]; then
  export PATH="$MASON_BIN_DIR:$PATH"
fi

cd "$ROOT_DIR"

printf '==> luacheck\n'
luacheck init.lua lua/ after/

printf '\n==> stylua\n'
stylua init.lua lua/ after/

printf '\n==> lua-language-server --check\n'
lua-language-server --check init.lua lua/ after/

printf '\n==> live lua_ls diagnostics\n'
nvim --headless \
  "+lua dofile(vim.fs.joinpath(vim.fn.stdpath('config'), 'scripts/live_luals.lua'))" \
  +qa
