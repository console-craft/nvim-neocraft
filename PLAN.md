# Neocraft Plan

## Philosophy

- Neocraft should be explicit, readable, and low-magic: closer to Kickstart's "you can understand the whole config" model than to a distro/framework.
- Neocraft should be Neovim `0.12+` native-first: prefer built-in primitives like `vim.pack`, `vim.lsp`, `vim.diagnostic`, `vim.fs`, and only add plugins where they clearly improve the experience.
- Neocraft should be mini-first: use `mini.nvim` modules as the default UX layer whenever they are good enough.
- LazyVim is reference material, not architecture: borrow only a few contained ideas like root detection patterns or tiny helper abstractions where they clearly add value and can be copied explicitly.
- Kickstart and MiniMax are the main stylistic guides:
  - Kickstart for explicit structure, simplicity, and readable control flow
  - MiniMax for `0.12+` primitives, `vim.pack`, and a mini-centric plugin philosophy

## Reference Sources

- Keep these repos in the workspace as reference material during implementation:
  - `../kickstart.nvim`
  - `../LazyVim`
  - `../MiniMax`
- Use them intentionally:
  - `../kickstart.nvim` for readable architecture, LSP attach patterns, and restrained scope
  - `../MiniMax` for `vim.pack`, native `0.12` APIs, mini module choices, and practical helper ideas
  - `../LazyVim` only for selected utilities or patterns worth copying into small explicit local modules

## Non-Goals

- No distro-style framework behavior
- No hidden import layers or plugin-spec auto-discovery as the primary architecture
- No persistent config state outside Lua source, like LazyVim-style JSON extras toggles
- No session files inside project directories
- No manual installation of LSP servers/linters/formatters

## Target Shape

- `init.lua`
- `lua/neocraft/config/options.lua`
- `lua/neocraft/config/autocmds.lua`
- `lua/neocraft/config/keymaps.lua`
- `lua/neocraft/actions.lua`
- `lua/neocraft/pickers.lua`
- `lua/neocraft/visits.lua`
- `lua/neocraft/terminal.lua`
- `lua/neocraft/worktrees.lua`
- `lua/neocraft/core/helpers.lua`
- `lua/neocraft/core/pack.lua`
- `lua/neocraft/core/root.lua`
- `lua/neocraft/core/sessions.lua`
- `lua/neocraft/plugins/mini.lua`
- `lua/neocraft/plugins/treesitter.lua`
- `lua/neocraft/plugins/lsp.lua`
- `lua/neocraft/plugins/format.lua`
- `lua/neocraft/plugins/git.lua`
- `after/lsp/*.lua`
- Optional later:
  - `lua/neocraft/lang/*.lua`
  - `after/ftplugin/*.lua`
  - `snippets/` and `after/snippets/`

## Architecture Rules

- `init.lua` should be the table of contents and explicitly `require(...)` each major module in order.
- Small helper functions should live in `core/helpers.lua`; explicit `require(...)` is still the default, with a tiny global `Lib` namespace allowed as a convenience alias for those helpers.
- `after/lsp/*.lua` is allowed specifically for server-specific LSP config, because that matches the Neovim `0.12` model well.
- Plugin registration should be explicit and centralized enough that you can answer "what is installed and why?" by reading a small set of files.

## Plugin Strategy

- Base package manager: `vim.pack`
- LSP/tool stack:
  - `neovim/nvim-lspconfig`
  - `mason.nvim`
  - `mason-lspconfig.nvim`
  - `mason-tool-installer.nvim`
- Formatting/linting baseline:
  - `conform.nvim`
  - rely on LSP diagnostics first
  - skip `nvim-lint` in v1
- Syntax/tooling baseline:
  - `nvim-treesitter`
- Completion/snippets baseline:
  - `mini.completion`
  - `mini.snippets`
  - `friendly-snippets`
- Git baseline:
  - `mini.git`
  - `mini.diff`
- Mini baseline should likely include:
  - `mini.basics`
  - `mini.icons`
  - `mini.notify`
  - `mini.statusline`
  - `mini.tabline`
  - `mini.pick`
  - `mini.files`
  - `mini.clue`
  - `mini.ai`
  - `mini.surround`
  - `mini.bufremove`
  - `mini.sessions`
  - likely `mini.extra`, `mini.pairs`, `mini.keymap`, maybe `mini.hipatterns`

## Session Philosophy

- Sessions should be global, not per-project filesystem artifacts.
- Store session files under a Neovim XDG path, preferably something like `stdpath("state") .. "/sessions"` or an equivalent dedicated session directory.
- Session identity should be derived from project location/root, not stored inside the project.
- Session filenames should be mapped from the full normalized project root path in a stable filesystem-safe way, so identically named projects in different directories stay distinct.
- Session behavior should work with your root helper, so "this project" resolves consistently for session save/load/delete.
- This keeps project folders clean and makes sessions feel like editor state, not repository content.

## Root Philosophy

- Use a lightweight local root helper.
- Detect roots for LSP, pickers, sessions, and tool behavior.
- Do not automatically change global cwd on every file open.
- Borrow the idea from LazyVim and MiniMax, but keep implementation tiny and explicit.

## Why `nvim-lspconfig` Still Stays

- Neovim `0.12+` provides the client primitives, but not the full maintained catalog of server defaults and quirks.
- `nvim-lspconfig` still provides the practical server definitions: commands, filetypes, root markers, and upstream integration knowledge.
- The intended model is:
  - Neovim core runs LSP
  - `nvim-lspconfig` provides server recipes
  - Neocraft customizes them in `after/lsp/*.lua`
- This keeps the config native without reinventing server definitions.

## Why the Full Mason Stack

- `mason.nvim` satisfies the requirement to avoid manual installation.
- `mason-lspconfig.nvim` makes LSP server name mapping and setup far cleaner.
- `mason-tool-installer.nvim` is worth including because you want auto-install from an explicit list, not a manual `:Mason` workflow.
- This gives Neocraft one readable source of truth for external tools.

## Implementation Stages

### Stage 1: Principles And Skeleton

- Create the explicit module layout.
- Make `init.lua` load the config in a visible order.
- Set the core conventions:
  - Neovim `0.12+` only
  - `vim.pack`
  - explicit requires, with `Lib` as the tiny helper namespace exception
  - mini-first UX
  - hybrid LSP layout with `after/lsp/*.lua`

### Stage 2: Core Helpers

- Add a small `core/helpers.lua` with only lightweight utilities actually needed.
- Likely helpers:
  - `now`
  - `later`
  - `augroup`
  - `autocmd`
- Expose them through a tiny global `Lib` namespace while keeping `core/helpers.lua` as the source of truth.
- These should be inspired by MiniMax, but much smaller and kept infrastructure-only.

### Stage 3: Base Editor Config

- Move current `nvim-neocraft/init.lua:1` settings into structured modules.
- Build:
  - `options.lua`
  - `autocmds.lua`
  - `keymaps.lua`
- Start with a conservative, readable baseline:
  - line numbers
  - split behavior
  - clipboard
  - diagnostics defaults
  - search behavior
  - undo/history
  - UI defaults
- Keep comments readable, not tutorial-heavy.
- Defer option families that depend on later stages:
  - revisit completion-related options in Stage 11 (`complete`, `completeopt`, `completetimeout`)
  - revisit fold defaults in Stage 8 once tree-sitter and textobjects are in place
    - current landing: keep `foldenable = true`, `foldcolumn = "0"`, `foldlevel = 99`, `foldlevelstart = 99`, `foldtext = ""`
    - use tree-sitter foldexpr when `folds` queries exist and fall back to `foldmethod = "indent"` otherwise
  - revisit session-related options in Stage 7 (`sessionoptions`)
  - revisit formatting-specific options in Stage 12 (`formatexpr`)
  - revisit statusline/message UI options in Stage 5 or Stage 14 (`laststatus`, `statuscolumn`, `shortmess`)
  - revisit taste-based defaults in Stage 14 (`conceallevel`, `smoothscroll`, `mousescroll`)
  - revisit prose-vs-code width rules once `after/ftplugin/*.lua` is in use: keep global code `colorcolumn = "120"`, but give prose buffers like Markdown/Text a local `textwidth = 80` with `colorcolumn = "+1"`

| Option(s)                                                    | MiniMax | LazyVim | Description                                                                             |
|--------------------------------------------------------------|---------|---------|-----------------------------------------------------------------------------------------|
| complete, completeopt, completetimeout, infercase            | yes     | yes-ish | These tie into completion UX, which you plan to shape in Stage 11 with mini.completion. |
| Fold defaults (foldmethod, foldlevel, foldnestmax, foldtext) | yes     | yes     | Better decided once treesitter and your folding preferences are in place.               |
| shortmess tweaks                                             | yes     | yes     | Good, but easy to over-tune before statusline/UI settles.                               |
| conceallevel = 2                                             | no      | yes     | Great for Markdown, but many people find it surprising in prose/config files.           |
| smoothscroll = true                                          | no      | yes     | Nice modern feel, but definitely taste.                                                 |
| mousescroll = "ver:25,hor:6"                                 | yes     | no      | Pure preference.                                                                        |
| laststatus = 3                                               | no      | yes     | Really belongs with your future statusline/UI layer.                                    |
| sessionoptions                                               | no      | yes     | Better handled when Stage 7 sessions are real.                                          |

### Stage 4: `vim.pack` Bootstrap

- Add a dedicated `core/pack.lua`.
- Define how plugins are declared and grouped.
- Track a lockfile policy for `vim.pack`.
- Keep plugin registration explicit and inspectable.

### Stage 5: Mini Core UX

- Install and configure the base mini modules that define the everyday editing experience.
- Focus on:
  - editing ergonomics
  - file navigation
  - discoverability
  - status/tab UI
  - notifications
  - buffer management
- Include low-friction command-line and cursor feedback polish here:
  - `mini.cursorword`
- Keep this the main UX layer, so Neocraft feels coherent rather than plugin-fragmented.

### Stage 6: Keymap Language

- Define a hybrid keymap language instead of a fully namespaced tree:
  - reserve a small set of `<Leader>{single-key}` mappings for truly hot-path actions
  - use namespaces only for broader or colder workflow families
  - avoid junk-drawer prefixes like a generic `other` bucket
- Stage 6 should establish the shape, not force every future workflow to have a prefix immediately.
- Initial Stage 6 layout:
  - `\` = editor toggles
  - hot-path singletons for things like splits/close and later files/grep/picker entrypoints
  - earned namespaces for:
    - buffer
    - tabs
    - lists
  - let `<Leader>g` grow nested workflow groups only when they earn it:
    - bisect
    - cherry-pick
    - rebase
    - destructive remove/reset flows
    - worktrees
  - reserve future meanings without binding them until the backing behavior exists:
    - code
    - focus list / "x marks the spot"
- Use `mini.clue` for discoverability rather than a heavier external helper.
- Keep mappings explicit, mnemonic, and command-first when an action is rare.
- Favor vim-surround-style surround verbs over `mini.surround` defaults:
  - `ys` add
  - `ds` delete
  - `cs` change
  - `S` in Visual mode to surround the current selection
  - keep surround search deterministic with `search_method = "cover"`
- Reserve plain `s` for `mini.jump2d` so it acts as the primary in-window jump motion.
- Keep the action picker as the home for global non-`<Leader>` mappings that are useful but easy to forget.
- Notifications history and `vim.pack` introspection can later graduate into a dedicated list namespace instead of an `other` bucket.
- Reserve `<Leader><Leader>` as the premium entrypoint for a future curated focus list once Stage 7 adds the backing store.
- Add motion-oriented extras here once the keymap language is settled:
  - `mini.jump2d`

### Stage 7: Files, Search, Git, Sessions, Root

- Configure:
  - `mini.pick`
  - `mini.files`
  - `mini.git`
  - `mini.diff`
  - `mini.sessions`
  - `mini.visits`
  - local `root` helper
  - local `worktrees` helper
- Stage 7 should stay root-aware without becoming cwd-driven:
  - detect project roots explicitly
  - scope pickers, sessions, visits, terminal startup, and file explorer fallbacks from the root helper
  - do not automatically `:cd` or restore `curdir` from sessions
- Power the Stage 6 hot-path search/navigation lane here:
  - `<Leader>f` find files
  - `<Leader>/` grep live
  - `<Leader>*` grep current word
  - `<Leader>r` resume picker
  - `<Leader>p` choose from all registered pickers
  - `<C-p>` curated action picker for hidden keymaps and command-first workflows
  - `<C-x>` file explorer, opening around the current file when possible and falling back to project root otherwise
- Make `mini.files` feel like a real project explorer without growing a wrapper abstraction:
  - keep `<CR>` as the primary open action in the target window
  - add `<C-s>` / `<C-v>` for split opens that keep the explorer open
  - add `g.` for hidden files, `gy` / `gY` for project-relative and absolute path copy, and `gx` for OS open
- Use `mini.visits` to back the curated working-set / focus-list idea:
  - keep the list file-based and let Neovim's last-position restore handle intra-file return points
  - track visits per detected project root instead of per cwd
  - use a dedicated `focus` label for the curated list
  - `<Leader><Leader>` open the current project focus list
  - `<Leader>xa` add current file to the focus list
  - `<Leader>xc` remove current file from the focus list
  - `<Leader>xd` clear the current project focus list
- Land the first full `<Leader>g` workflow families here as `mini.git` and `mini.diff` become available.
- Keep `go` as the contextual Git "open at cursor" action backed by `mini.git.show_at_cursor()`.
- Keep `mini.diff` hunk operators as the primary low-level hunk language, but wrap hunk motions on `[h` / `]h` / `[H` / `]H` to recenter and show transient hunk counts.
- Add pending-file motions on `[g` / `]g` for unstaged files and `[G` / `]G` for staged files.
- Let Git workflows grow into explicit subgroups when they prove useful:
  - `<Leader>gb` for bisect
  - `<Leader>gp` for cherry-pick
  - `<Leader>gr` for rebase
  - `<Leader>gR` for destructive branch/reset cleanup with stronger confirmations
- Add centralized worktree management as an editor-local workflow:
  - store worktrees under `~/.worktrees/<project-slug>/...`, derived from the main repo path rather than scattered next to repos
  - `<Leader>gwa` create from a picked base and prompt for a worktree name
  - `<Leader>gwr` remove a picked worktree
  - `<Leader>gwy` yank a picked worktree path
  - `<Leader>gwc` copy selected project files into a picked worktree for ignored/local-only files like `.env`
  - `<Leader>gwp` prune stale worktree metadata
- Promote notifications history and `vim.pack` introspection into the list namespace on `<Leader>ln` and `<Leader>lp`, while still surfacing global non-`<Leader>` actions through `<C-p>`.
- Add a lightweight floating terminal entrypoint on `<C-/>` / `<C-_>`; reuse one floating terminal buffer globally, start it in detected project root, and avoid a full terminal namespace unless it proves necessary.
- Add session behavior tied to detected project roots, with storage in XDG state paths.
- Make sessions automatic for bare `nvim` startup and normal exit:
  - restore the current project session on bare startup if it exists
  - otherwise start fresh and create it on exit
  - add a one-shot "restart fresh" flow which discards the current project session before restart
- Treat `mini.extra` list pickers as generic building blocks, but add explicit `quickfix_list` and `location_list` wrappers for discovery in the picker browser.
- Ensure search/navigation uses root information without forcing cwd changes.
- If `mini.pick` benefits from it, treat `mini.fuzzy` as an internal implementation detail here rather than as a separate UX layer.

### Stage 8: Treesitter

- Landed shape:
  - use `nvim-treesitter` from the `main` branch
  - keep parser installation explicit in `plugins/treesitter.lua`, but allow the curated list to grow beyond the minimal baseline when it reflects real use
  - include `nvim-treesitter-textobjects` to support query-backed textobjects already used by `mini.ai`
  - include `nvim-treesitter-context` now, with the preferred old-config behavior: `trim_scope = "inner"`, `mode = "topline"`, `max_lines = 2`
- Attach tree-sitter explicitly on `FileType`:
  - resolve the effective parser language from the buffer filetype
  - call `vim.treesitter.start()` only when a parser exists
  - avoid turning parser/query management into a giant implicit system
- Enable structure-aware features only when queries exist:
  - use tree-sitter folds when `folds` queries exist
  - use tree-sitter `indentexpr` when `indents` queries exist
  - fall back to indent folding when tree-sitter folds are unavailable
- Keep folded lines rendered normally for now with `foldtext = ""`; richer fold summaries or gutter counts are intentionally deferred to avoid extra UI machinery.
- Add a small set of filetype aliases here because they directly improve parser/query coverage:
  - `.env` and `.env.*` -> `sh`
  - `docker-compose*.yml|yaml` and `compose*.yml|yaml` -> `yaml.docker-compose`
  - `*.component.html` and `*.container.html` -> `htmlangular`
  - `.mdc` -> `markdown`
- Revisit `mini.indentscope` here once tree-sitter, folding, and code-structure UX are in place:
  - enable it with a subtle `│` guide and `try_as_border = true`
  - disable it in prose buffers and special buffers rather than carrying a large exclusion matrix

### Stage 9: Native LSP + Mason

- Build `plugins/lsp.lua` as the shared LSP/tooling entrypoint.
- Configure:
  - `mason.nvim`
  - `mason-lspconfig.nvim`
  - `mason-tool-installer.nvim`
  - `nvim-lspconfig`
- Define:
  - a central list of LSP servers
  - a central list of external tools to auto-install
  - a Kickstart-style `LspAttach` callback for buffer-local mappings and capability-based features
- Use `<Leader>c` as the shared code namespace for LSP-native actions.
- Start with hover, rename, code action, definitions/references, diagnostics, and formatting.
- Revisit `mini.files` file operations here: when files are renamed or moved through `mini.files`, notify supporting LSP clients with `workspace/willRenameFiles` / `workspace/didRenameFiles` so servers can update imports and related references.
- Keep that integration LSP-owned and explicit in `plugins/lsp.lua`, not embedded as a bigger `mini.files` abstraction.
- If tests or debug workflows are later added, fit them under `<Leader>c` only when they prove common enough.
- After adding buffer-local code mappings, refresh `mini.clue` triggers for those buffers during `LspAttach` if needed.
- Use Neovim-native `vim.lsp.config()` / `vim.lsp.enable()` patterns.

### Stage 10: Server-Specific LSP Files

- Put server-specific details in `after/lsp/*.lua`.
- Initial likely files:
  - `after/lsp/lua_ls.lua`
  - `after/lsp/ts_ls.lua` or whichever TS server is chosen
  - `after/lsp/pyright.lua` or whichever Python server is chosen
- Keep `plugins/lsp.lua` generic and shared; keep per-server quirks out of it.

### Stage 11: Completion And Snippets

- Configure:
  - `mini.completion`
  - `mini.snippets`
  - `friendly-snippets`
- Make completion feel mini-native and lightweight.
- Add snippet loading from config paths so personal snippets can later live in:
  - `snippets/`
  - `after/snippets/`
- Keep this intentionally simpler than a `blink.cmp`-style stack unless a clear gap appears later.

### Stage 12: Formatting

- Add `conform.nvim`.
- Define formatters by filetype.
- Feed those formatter binaries into the Mason tool list.
- Let formatting be explicit and declarative.

### Stage 13: V1 Language Profiles

- First-class language/tooling groups:
  - Core authoring: Lua, Markdown, JSON/YAML, TOML, Bash, Git commit messages
  - JavaScript/TypeScript
  - Python
- Each group should define:
  - LSP servers
  - formatter tools
  - any filetype-specific UX tweaks
- Core authoring filetypes should likely carry local width rules, like Markdown/Text using `textwidth = 80` and `colorcolumn = "+1"`, while code keeps the global `colorcolumn = "120"` guide.
- Keep these grouped cleanly so future languages can be added without bloating core files.
- Consider `mini.hipatterns` here for authoring-focused pattern highlights like TODO/NOTE markers and color literals.

### Stage 14: Quality And Health

- Add a few practical user commands or checks if useful.
- Ensure the config has:
  - reproducible plugin state
  - readable failure points
  - a clear way to understand what tools are expected
- Avoid building a framework; just add enough diagnostics to keep the config maintainable.
- Optional late-stage polish once the main UX is stable:
  - `mini.map` for overview/navigation, after diagnostics and diff integrations are already useful
  - `mini.animate` only if it still feels worth the tradeoffs, since it can introduce visual and performance side effects
  - `mini.base16` if Neocraft wants a small in-repo colorscheme workflow rather than only consuming external themes

### Stage 15: Documentation And Upgrade Story

- Add short comments that explain:
  - architecture choices
  - why a plugin exists
  - where to put future customizations
- Mention the reference directories in the docs/comments so future work can reuse:
  - `./kickstart.nvim`
  - `./LazyVim`
  - `./MiniMax`
- Document the philosophy explicitly:
  - "Kickstart-like readability"
  - "MiniMax-like native + mini-first tooling"
  - "LazyVim used only as selective reference"

## Likely V1 Defaults

- Package manager: `vim.pack`
- Completion: `mini.completion`
- Snippets: `mini.snippets` + `friendly-snippets`
- Formatting: `conform.nvim`
- Linting: LSP diagnostics first
- Roots: helper only, no cwd auto-switch
- Sessions: global XDG state storage by project-root mapping
- Search/files: `mini.pick` + `mini.files`
- Git: `mini.git` + `mini.diff`, with explicit bisect/cherry-pick/rebase/remove subgroups
- Worktrees: centralized under `~/.worktrees` with project-derived slugs and picker-driven add/remove/yank/copy-file flows
- Focus list: `mini.visits` with root-scoped file labels
- Terminal: one reusable floating terminal on `<C-/>`
- Hidden actions: curated picker on `<C-p>` for global non-`<Leader>` mappings
- Lists: `<Leader>ln` for notifications history, `<Leader>lp` for `vim.pack` summary
- Discoverability: `mini.clue`
- UI/status: mini modules first
- External tools: auto-installed by Mason from declared lists

## What This Plan Optimizes For

- A config you can fully understand and evolve yourself
- Minimal architectural magic
- Strong default UX with a small plugin surface
- Clear separation between generic editor behavior and language-specific behavior
- Native Neovim `0.12+` direction without losing practical conveniences
