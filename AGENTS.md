# Neocraft

Personal Neovim `0.12+` configuration focused on explicit structure, native APIs, and a mini-first UX.

## Project Principles

- Keep the config readable and low-magic: closer to Kickstart than to a distro/framework.
- Prefer Neovim built-ins first: `vim.pack`, `vim.lsp`, `vim.diagnostic`, `vim.fs`, and native autocmd/keymap APIs.
- Use `mini.nvim` modules as the default UX layer when they are good enough.
- Borrow ideas from reference configs selectively, but copy patterns into small local modules instead of adding framework behavior.

## Architecture

- `init.lua` is the table of contents; keep startup order explicit with plain `require(...)` calls.
- `lua/neocraft/config/*.lua` contains baseline editor behavior: options, autocmds, and keymaps.
- `lua/neocraft/core/*.lua` contains small infrastructure modules only.
- `lua/neocraft/plugins/*.lua` owns plugin registration and plugin-family setup.
- `after/lsp/*.lua` is reserved for server-specific LSP configuration.
- Keep plugin registration inspectable: it should be easy to answer what is installed and why.

## Plugin And Tooling Conventions

- Package manager: `vim.pack`.
- Commit `nvim-pack-lock.json`; do not hand-edit it.
- Keep plugin declarations grouped by purpose, not scattered across unrelated files.
- Avoid hidden import layers, plugin auto-discovery, or persistent config state outside source files.
- Prefer LSP diagnostics first; add extra linting only when it clearly improves the experience.
- External language tools should be installed through Mason-based automation, not manual setup.

## Editing Conventions

- Keep helpers tiny and infrastructure-focused.
- `Lib` is the only intended global convenience namespace; `lua/neocraft/core/helpers.lua` remains the source of truth.
- Favor explicit code over clever abstractions.
- Keep comments short and architectural; avoid tutorial-style noise.
- Default code width is guided by `colorcolumn = "120"`; prose-specific width rules belong in filetype-local config.

## Roots And Sessions

- Root detection should be lightweight and explicit.
- Do not automatically change global cwd on every file open.
- Sessions are editor state, not project artifacts.
- Store sessions under an XDG Neovim state path, not inside repositories.
- Session identity should derive from the detected project root.

## Repo Map

- `init.lua`: startup entrypoint and load order.
- `lua/neocraft/config/options.lua`: baseline options and diagnostic defaults.
- `lua/neocraft/config/autocmds.lua`: general editor autocmds.
- `lua/neocraft/config/keymaps.lua`: global keymaps.
- `lua/neocraft/core/helpers.lua`: `Lib` helpers.
- `lua/neocraft/core/pack.lua`: `vim.pack` helpers and plugin grouping.
- `lua/neocraft/core/root.lua`: root detection helpers.
- `lua/neocraft/core/sessions.lua`: session storage and project-session behavior.
- `lua/neocraft/plugins/mini.lua`: `mini.nvim` bootstrap and setup.
- `lua/neocraft/plugins/treesitter.lua`: tree-sitter setup.
- `lua/neocraft/plugins/lsp.lua`: shared LSP and Mason entrypoint.
- `lua/neocraft/plugins/format.lua`: formatting setup.
- `lua/neocraft/plugins/git.lua`: Git UX setup.
- `after/lsp/`: per-server LSP overrides.

## Verification

- Before marking work as complete:
  - if code files or project config files were added or changed run the `/verify` command
  - if any type of file was added or changed run the `/diffs` command
