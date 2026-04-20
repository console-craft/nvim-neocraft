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
- `lua/neocraft/features/*.lua` owns editor workflows and integration behavior used by keymaps, autocmds, and plugin setup.
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
- `lua/neocraft/features/editing.lua`: editing motions, paste behavior, search counts, scroll behavior, diagnostics, and tag/LSP definition fallback.
- `lua/neocraft/features/editor.lua`: editor toggles, lists, dismiss behavior, terminal title, winbar labels, and restart/quit helpers.
- `lua/neocraft/features/workspace.lua`: buffer, window, tab, save, path-copy, and WezTerm-aware pane navigation helpers.
- `lua/neocraft/features/pickers/`: root-aware picker facade with core, extra/editor, action, and Git/worktree picker modules.
- `lua/neocraft/features/focus.lua`: root-scoped focus list behavior backed by `mini.visits` labels.
- `lua/neocraft/features/formatting.lua`: project-aware formatter detection, Conform formatter resolution, and formatting commands.
- `lua/neocraft/features/mini.lua`: `mini.files` explorer helpers and minimap toggle entrypoints.
- `lua/neocraft/features/treesitter.lua`: tree-sitter textobject motions and selection growth/shrink helpers.
- `lua/neocraft/features/terminal.lua`: reusable project-root floating terminal.
- `lua/neocraft/features/git/*.lua`: Git workflow actions for status, diff, hunks, pending files, branches, rebase, reset, bisect, cherry-pick, and worktrees.
- `lua/neocraft/features/lsp/*.lua`: shared LSP attach behavior plus Copilot, rename, annotations, TypeScript, and Python helpers.
- `lua/neocraft/lang/init.lua`: merges active language profiles and detects duplicate server/formatter declarations.
- `lua/neocraft/lang/base.lua`: baseline authoring LSP servers, Mason tools, and formatter mappings.
- `lua/neocraft/lang/typescript.lua`: TypeScript/JavaScript LSP, lint companion, tool, and formatter profile.
- `lua/neocraft/lang/python.lua`: Python LSP, Ruff, tool, formatter, and virtual-environment profile.
- `lua/neocraft/plugins/mini/init.lua`: `mini.nvim` registration and per-module setup entrypoint.
- `lua/neocraft/plugins/mini/*.lua`: individual `mini.nvim` module setup files.
- `lua/neocraft/plugins/ui.lua`: targeted non-mini UI/editor-polish plugins.
- `lua/neocraft/plugins/treesitter.lua`: tree-sitter plugin registration and setup.
- `lua/neocraft/plugins/lsp.lua`: shared LSP, Mason, and language-tooling entrypoint.
- `lua/neocraft/plugins/conform.lua`: `conform.nvim` formatting setup and project-aware formatter resolution.
- `lua/neocraft/plugins/git.lua`: `mini.git` and `mini.diff` setup.
- `lua/neocraft/theme/runtime.lua`: small runtime theme behavior such as mode-reactive UI highlights.
- `lua/neocraft/theme/util.lua`: theme utility helpers.
- `lua/neocraft/theme/gruvcraft/`: local gruvcraft palette and highlight layers for syntax, editor UI, and plugins.
- `lua/neocraft/health.lua`: `:checkhealth neocraft` checks.
- `colors/gruvcraft-dark.lua`: colorscheme entrypoint.
- `after/lsp/`: per-server LSP overrides.
- `after/ftplugin/`: filetype-local prose and formatting behavior.
- `scripts/checks.sh`: repo verification entrypoint.
- `scripts/runtime_diagnostics.lua`: headless Neovim runtime diagnostic check used by verification.
- `nvim-pack-lock.json`: committed `vim.pack` lockfile.

## Verification

- Before marking work as complete:
  - if code files or project config files were added or changed run the `/verify` command
