# Neocraft Plan

## Current State

Neocraft is now a working personal Neovim `0.12+` configuration rather than an early staged migration plan. The main shape is in place: explicit startup order, `vim.pack`, native LSP, Mason-managed external tools, mini-first UX, project-aware formatting, root-scoped sessions, Git workflows, a local theme, and repo verification.

This document should stay focused on the current architecture, the rules for future changes, and the few remaining directions that are still intentionally open.

## Philosophy

- Keep the config readable and low-magic: closer to Kickstart than to a distro/framework.
- Prefer Neovim built-ins first: `vim.pack`, `vim.lsp`, `vim.diagnostic`, `vim.fs`, native autocmds, and native keymaps.
- Use `mini.nvim` modules as the default UX layer when they are good enough.
- Treat LazyVim, Kickstart, and MiniMax as reference material, not architecture.
- Copy useful reference ideas into small local modules instead of importing framework behavior.

## Non-Goals

- No distro-style framework behavior.
- No hidden import layers or plugin-spec auto-discovery.
- No persistent config state outside source files, except normal editor/plugin state under XDG paths.
- No session files inside project directories.
- No manual installation of LSP servers, linters, or formatters when Mason automation can own it.
- No broad compatibility layers for old structure unless there is a concrete persisted-state or external-consumer need.

## Architecture

- `init.lua` is the table of contents and explicitly loads config, core helpers, plugin families, features, and theme in order.
- `lua/neocraft/config/*.lua` owns baseline options, autocmds, and global keymaps.
- `lua/neocraft/core/*.lua` owns infrastructure only: helpers, `vim.pack`, root detection, and sessions.
- `lua/neocraft/plugins/*.lua` owns plugin registration and plugin-family setup.
- `lua/neocraft/features/*.lua` owns behavior used by keymaps, autocmds, plugin setup, and commands.
- `lua/neocraft/lang/*.lua` owns declarative language profile data: LSP servers, Mason tools, and formatter mappings.
- `after/lsp/*.lua` owns server-specific LSP configuration.
- `after/ftplugin/*.lua` owns filetype-local prose and formatting behavior.
- `lua/neocraft/theme/*` owns the local gruvcraft colorscheme and tiny runtime theme behavior.

## Current Repo Shape

- `init.lua`: startup entrypoint and load order.
- `lua/neocraft/config/options.lua`: global options, diagnostics, and feature flags.
- `lua/neocraft/config/autocmds.lua`: general editor autocmds.
- `lua/neocraft/config/keymaps.lua`: global keymaps and `mini.clue` group metadata.
- `lua/neocraft/core/helpers.lua`: tiny `Lib` helper namespace.
- `lua/neocraft/core/pack.lua`: `vim.pack` grouping, update hooks, and pack summary UI.
- `lua/neocraft/core/root.lua`: lightweight root detection based on LSP roots, project markers, and cwd fallback.
- `lua/neocraft/core/sessions.lua`: project-session storage under XDG state paths.
- `lua/neocraft/features/editing.lua`: movement, paste behavior, search count UI, scroll behavior, diagnostics, and definition/tag fallback.
- `lua/neocraft/features/editor.lua`: toggles, list helpers, UI dismissal, terminal title, winbar labels, restart, and quit helpers.
- `lua/neocraft/features/workspace.lua`: buffer, window, tab, save, path-copy, and WezTerm-aware pane navigation helpers.
- `lua/neocraft/features/pickers/`: root-aware picker facade with core, extra/editor, action, and Git/worktree picker modules.
- `lua/neocraft/features/focus.lua`: root-scoped focus list behavior backed by `mini.visits` labels.
- `lua/neocraft/features/formatting.lua`: project-aware formatter detection, Conform formatter resolution, `gq`, and formatting commands.
- `lua/neocraft/features/mini.lua`: `mini.files` explorer behavior and minimap toggles.
- `lua/neocraft/features/treesitter.lua`: textobject movement and tree-sitter selection helpers.
- `lua/neocraft/features/terminal.lua`: reusable project-root floating terminal.
- `lua/neocraft/features/git/*.lua`: Git status, diff, hunks, pending files, branch cleanup, rebase, reset, bisect, cherry-pick, and centralized worktree workflows.
- `lua/neocraft/features/lsp/*.lua`: LSP attach behavior, Copilot/NES, file rename notifications, annotations, TypeScript helpers, and Python helpers.
- `lua/neocraft/lang/init.lua`: active language profile merge and duplicate declaration checks.
- `lua/neocraft/lang/base.lua`: baseline authoring servers, tools, and formatter mappings.
- `lua/neocraft/lang/typescript.lua`: TypeScript/JavaScript servers, lint companions, tools, and formatter mappings.
- `lua/neocraft/lang/python.lua`: Python servers, Ruff tools, formatters, and virtual-environment integration.
- `lua/neocraft/plugins/mini/init.lua`: mini.nvim registration and per-module setup entrypoint.
- `lua/neocraft/plugins/mini/*.lua`: individual mini module setup files.
- `lua/neocraft/plugins/ui.lua`: targeted non-mini UI/editor-polish plugins.
- `lua/neocraft/plugins/treesitter.lua`: tree-sitter plugin registration, parser list, attach behavior, context, textobjects, and autotag setup.
- `lua/neocraft/plugins/lsp.lua`: Mason, LSP server enablement, shared capabilities, venv-selector, and LSP feature wiring.
- `lua/neocraft/plugins/conform.lua`: Conform registration, project-aware formatter roots, and format-on-save policy.
- `lua/neocraft/plugins/git.lua`: `mini.git` and `mini.diff` setup.
- `lua/neocraft/theme/gruvcraft/`: palette and highlight layers for syntax, editor UI, and plugins.
- `lua/neocraft/theme/runtime.lua`: mode-reactive runtime highlight behavior.
- `lua/neocraft/theme/util.lua`: theme utility helpers.
- `lua/neocraft/health.lua`: `:checkhealth neocraft` checks.
- `colors/gruvcraft-dark.lua`: colorscheme entrypoint.
- `after/lsp/*.lua`: per-server LSP overrides.
- `after/ftplugin/*.lua`: prose and formatting filetype behavior.
- `scripts/checks.sh`: repo verification entrypoint.
- `scripts/runtime_diagnostics.lua`: headless Neovim runtime diagnostic check used by verification.
- `nvim-pack-lock.json`: committed `vim.pack` lockfile.

## Runtime Model

- Startup stays explicit and readable in `init.lua`.
- `Lib.now(...)` is for setup that must run immediately.
- `Lib.later(...)` is for non-critical plugin setup that can defer.
- Global convenience stays limited to `Lib`.
- Features should be required by keymaps or plugin setup directly; avoid registry/autodiscovery layers.
- Plugin files should answer what is installed and why.
- Feature files should answer what behavior Neocraft adds on top.

## Keymap Model

- Hot-path actions use direct leader mappings where they are common enough.
- Broader workflow families use earned namespaces like `<Leader>b`, `<Leader>c`, `<Leader>g`, `<Leader>l`, and `<Leader>x`.
- Toggles live under `\`.
- The action picker on `<C-p>` is the home for discoverable but less memorable global actions.
- `mini.clue` provides discovery; avoid adding a heavier keymap framework.
- Keep keymaps explicit and command-first when the action is rare.

## Roots And Sessions

- Root detection is lightweight and explicit.
- The default root order is active LSP roots, project markers, then cwd.
- Pickers, formatting, sessions, focus lists, terminal startup, and Git helpers use the root helper where useful.
- Neocraft does not auto-change global cwd on every file open.
- Sessions are editor state, not project artifacts.
- Session files live under Neovim state paths and are keyed by detected project root.

## Plugin Strategy

- Package manager: `vim.pack`.
- Commit `nvim-pack-lock.json`; do not hand-edit it.
- Mini baseline: notify, icons, statusline, tabline, clue, map, animate, extra, ai, surround, jump2d, completion, indentscope, cursorword, pairs, hipatterns, bufremove, sessions, visits, files, and pick.
- UI complements: `guess-indent.nvim`, `indent-blankline.nvim`, `virt-column.nvim`, and `render-markdown.nvim`.
- Tree-sitter stack: `nvim-treesitter` main branch, textobjects, context, and `nvim-ts-autotag`.
- LSP/tool stack: `nvim-lspconfig`, `mason.nvim`, `mason-lspconfig.nvim`, `mason-tool-installer.nvim`, `SchemaStore.nvim`, and `venv-selector.nvim`.
- Formatting stack: `conform.nvim` with project-aware formatter roots and LSP fallback where configured.
- Git stack: `mini.git` and `mini.diff`, with local feature modules for higher-level workflows.
- Completion stack: `mini.completion`, built-in `vim.snippet`, native `vim.lsp.inline_completion`, and Copilot through the native LSP client.

## Language Strategy

- Language profile data stays declarative in `lua/neocraft/lang/*.lua`.
- Runtime behavior stays in plugin setup, feature modules, `after/lsp/*.lua`, and `after/ftplugin/*.lua`.
- `lang/init.lua` merges active profiles, rejects duplicate server and formatter declarations, and dedupes Mason tools.
- Base profile owns Lua, JSON, YAML, shell, TOML, Markdown, Docker, GitHub Actions, and general authoring defaults.
- TypeScript profile owns `vtsls` plus config-aware `eslint`, `biome`, and `oxlint` companions.
- Python profile owns `basedpyright`, `ruff`, `black`, `isort`, and virtual-environment selection.
- Prefer LSP diagnostics first; add extra linting only when it clearly improves the experience.

## Formatting Strategy

- Conform is the formatting entrypoint for manual formatting, save formatting, and formatter-aware `gq`.
- Project formatter config wins over Neocraft defaults when detected inside the project root.
- Formatter family precedence is currently `prettier`, `oxfmt`, `biome`, then `ruff` where applicable.
- Lua uses `stylua`; shell uses `shfmt`; TOML falls back to `taplo`; Markdown falls back to `mdformat`.
- JS/TS and JSON/YAML can use project formatters or LSP fallback depending on configured filetype policy.
- Python uses explicit Ruff format config when present; otherwise it falls back to `isort` and `black`.
- Save-time formatting skips prose buffers like Markdown, plain text, and Git commit messages.

## Git And Worktrees

- Low-level Git UI comes from `mini.git` and `mini.diff`.
- Neocraft feature modules provide explicit workflow commands for status, logs, diff, hunks, pending files, staging, commit, rebase, cherry-pick, bisect, branch cleanup, and reset flows.
- Destructive Git flows should keep stronger confirmations.
- Worktrees are centralized under `~/.worktrees/<project-slug>/...` instead of scattered next to repositories.
- Worktree helpers should remain editor-local workflow conveniences, not a general Git abstraction layer.

## Theme Strategy

- `gruvcraft-dark` is the local colorscheme entrypoint.
- `mini.base16` supplies the base palette mechanics.
- `lua/neocraft/theme/gruvcraft/*` owns explicit highlight layers for syntax, editor UI, and plugins.
- Runtime theme behavior should stay tiny and theme-owned.
- Keep the structure ready for a future `gruvcraft-light` variant without turning the theme into a framework.

## Verification

- `scripts/checks.sh` is the repository verification entrypoint.
- Verification covers formatting, linting, LuaLS checks, and runtime diagnostics.
- Run `/verify` before considering code or project configuration changes complete.
- Keep `lua/neocraft/health.lua` focused on useful runtime and maintainer checks.

## Near-Term Maintenance

- Keep the repo map in `AGENTS.md` and this plan aligned with future structural refactors.
- Reduce duplicated comments where module names already explain the behavior.
- Continue moving behavior into focused feature modules when plugin setup files start doing too much.
- Keep language profiles declarative; avoid slipping runtime decisions into profile data.
- Keep picker/action catalogs curated so `<C-p>` stays useful rather than becoming a dump.
- Revisit any remaining stale names after large refactors, especially docs that still mention old top-level modules or old plugin filenames.
