#!/usr/bin/env bash

# Repo verification entrypoint for Neocraft maintainers and agent-driven verification.

# ┌───────────────────────────────────────────┐
# │ Setup                                     │
# └───────────────────────────────────────────┘

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

export XDG_CONFIG_HOME="$(dirname -- "$ROOT_DIR")"
export NVIM_APPNAME="$(basename -- "$ROOT_DIR")"

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
MASON_BIN_DIR="$XDG_DATA_HOME/$NVIM_APPNAME/mason/bin"

if [[ -d "$MASON_BIN_DIR" ]]; then
  export PATH="$MASON_BIN_DIR:$PATH"
fi

cd "$ROOT_DIR"

# ┌───────────────────────────────────────────┐
# │ Run Checks                                │
# └───────────────────────────────────────────┘

printf '\n==> stylua\n'
stylua init.lua lua/ after/ colors/

printf '==> luacheck\n'
luacheck init.lua lua/ after/ colors/

printf '\n==> lua-language-server --check\n'
lua-language-server --check init.lua lua/ after/ colors/

printf '\n==> lua_ls runtime diagnostics\n'
nvim --headless \
  "+lua dofile(vim.fs.joinpath(vim.fn.stdpath('config'), 'scripts/runtime_diagnostics.lua'))" \
  +qa
