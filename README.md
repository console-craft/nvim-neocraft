# nvim-neocraft

Personal Neovim `0.12+` configuration focused on explicit structure, native APIs, and a mini-first UX.

## Features

- Uses Neovim built-ins first: `vim.pack`, `vim.lsp`, `vim.diagnostic`, `vim.fs`, and native keymap/autocmd APIs.
- Keeps startup explicit through `init.lua` instead of plugin auto-discovery or framework-style import layers.
- Uses `mini.nvim` modules as the default editor UX layer for files, pickers, statusline, completion, visits, Git signs, and related workflows.
- Includes a local `gruvcraft-dark` colorscheme with dedicated syntax, editor UI, plugin, and runtime highlight layers.
- Provides root-aware picker, focus-list, formatting, terminal, workspace, LSP, and Git workflow helpers under `lua/neocraft/features/`.
- Supports project-scoped sessions stored under Neovim state paths instead of inside repositories.
- Configures language tooling through small language profiles and Mason-based installation instead of one-off manual setup.
- Includes Git workflows for hunks, pending files, branches, rebase, reset, bisect, cherry-pick, worktrees, and Diffview integration.
- Includes TypeScript/JavaScript and Python profiles with LSP, formatter, lint, and virtual-environment behavior.
- Provides repo checks for formatting, linting, static Lua analysis, and live headless Neovim runtime diagnostics.

## Non-Goals

- Being a general-purpose Neovim distribution. This is a personal config with reusable patterns, not a framework.
- Hidden plugin discovery or persistent configuration state outside source files.
- Automatically changing global cwd on every file open. Root detection is used by features that need project context.
- Installing external language tools manually in ad-hoc plugin setup. Mason-based automation owns that path.

## Installation

Clone this repository as a named Neovim config:

```shell
git clone https://github.com/console-craft/nvim-neocraft ~/.config/nvim-neocraft
NVIM_APPNAME=nvim-neocraft nvim
```

Or use it as the default config:

```shell
git clone https://github.com/console-craft/nvim-neocraft ~/.config/nvim
nvim
```

Neocraft requires Neovim `0.12+`.

## Usage

Start Neovim with this config:

```shell
NVIM_APPNAME=nvim-neocraft nvim
```

Run health checks from inside Neovim:

```vim
:checkhealth neocraft
```

Update plugin lock data through Neovim's `vim.pack` workflow and commit `nvim-pack-lock.json` when plugin revisions change.

### SonarLint

SonarLint connections, project routes, analyzers, and filetypes are declared together in
`lua/neocraft/plugins/sonarlint.lua`. The integration is project-gated and uses connected quality profiles when
credentials are available, falling back to local analysis otherwise. Use `:SonarLintInfo` to inspect the route selected
for the current buffer; it does not trigger a project scan.

Machine-specific Sonar configuration comes from environment variables. Personal SonarQube Cloud uses
`SONAR_PERSONAL_URL`, `SONAR_PERSONAL_ORGANIZATION`, `SONAR_PERSONAL_REGION`, `SONAR_PERSONAL_REPOSITORY`, and paired
`SONAR_PERSONAL_{FRONTEND,BACKEND}_{PATH,PROJECT_KEY,MODE}` variables. Self-hosted work projects use `SONAR_WORK_URL`,
`SONAR_WORK_REPOSITORY`, and paired `SONAR_WORK_{FRONTEND,BACKEND}_{PATH,PROJECT_KEY,MODE}` variables. Empty or missing
connections and routes are ignored.

Tokens remain isolated in `SONAR_PERSONAL_TOKEN` and `SONAR_WORK_TOKEN`. Routes default to automatic mode; set their
optional `*_MODE` variable to `local` to force local analysis even when the matching token is available.

The text analyzer provides high-confidence exposed-secret detection across analyzed files; it is not a prose linter.
Sonar does not currently provide a Lua analyzer, so Lua diagnostics remain owned by LuaLS and Luacheck.

Sonar may overlap with ESLint, Biome, Oxlint, or Ruff on simpler code-smell rules. Keep Sonar enabled for connected
quality-profile parity and security findings, and tune duplicate rules in the Sonar profile rather than hiding an entire
diagnostic source.

The custom client imports internal `sonarlint.nvim` modules (`sonarlint.utils`, `sonarlint.scm`,
`sonarlint.autobinding`, `sonarlint.rules`, and `sonarlint.connected_mode`). These are not stable public APIs, so the
integration relies on the revision pinned in `nvim-pack-lock.json`; verify it before updating that pin.

## Quality Checks

Run the full repo verification suite:

```shell
./scripts/checks.sh
```

The check script runs:

- `stylua` over `init.lua`, `lua/`, `after/`, and `colors/`
- `luacheck` over the same Lua runtime paths
- `lua-language-server --check`
- A headless Neovim runtime diagnostics pass through `scripts/runtime_diagnostics.lua`

## Project Layout

- `init.lua`: startup entrypoint and explicit load order.
- `lua/neocraft/config/`: baseline options, autocmds, and keymaps.
- `lua/neocraft/core/`: small infrastructure helpers for `Lib`, plugin packs, roots, and sessions.
- `lua/neocraft/plugins/`: plugin registration and plugin-family setup.
- `lua/neocraft/features/`: editor workflows used by keymaps, autocmds, and plugin setup.
- `lua/neocraft/features/git/`: Git actions for status, diffs, hunks, pending files, branches, rebase, reset, bisect, cherry-pick, and worktrees.
- `lua/neocraft/features/lsp/`: shared LSP attach behavior plus Copilot, rename, annotation, SonarLint, TypeScript, and Python helpers.
- `lua/neocraft/lang/`: language profiles for LSP servers, Mason tools, and formatters.
- `lua/neocraft/theme/gruvcraft/`: local palette and highlight layers.
- `after/lsp/`: server-specific LSP overrides.
- `after/ftplugin/`: filetype-local behavior.
- `colors/gruvcraft-dark.lua`: colorscheme entrypoint.
- `scripts/`: verification and runtime diagnostic tooling.
- `nvim-pack-lock.json`: committed `vim.pack` lockfile.

## Tech Stack

- Neovim `0.12+`
- Lua
- `vim.pack`
- `mini.nvim`
- Mason / LSP / Tree-sitter / Conform
- StyLua, Luacheck, and Lua Language Server

## License

MIT.

See `LICENSE.txt` for the full license text.
