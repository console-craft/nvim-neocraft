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
- Session filenames should be mapped from project root in a stable way, likely encoded or hashed from the absolute path.
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
  - reserve future meanings without binding them until the backing behavior exists:
    - code
    - git/hunks
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
- Keep rare/admin actions out of leader space for now:
  - notifications stay command-first
  - `vim.pack` introspection stays command-first
  - surface those later through the action picker instead of an `other` namespace
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
- Power the Stage 6 hot-path search/navigation lane here:
  - `<Leader>f` find files
  - `<Leader>g` grep live
  - `<Leader>*` grep current word
  - `<Leader>r` resume picker
  - `<Leader>p` choose picker
  - `<C-p>` action picker for important commands and mapped workflows
  - `<C-x>` file explorer
- Use `mini.visits` to back the curated working-set / focus-list idea:
  - `<Leader><Leader>` open the current focus list
  - `<Leader>xa` add current file/location
  - `<Leader>xd` remove current file/location
  - decide here whether that list is file-based or exact-location-based
- Land the first `<Leader>h` Git mappings here as `mini.git` and `mini.diff` become available.
- Keep notifications and `:NeocraftPack` command-first, but surface them through the action picker.
- Add a lightweight floating terminal entrypoint on `<C-/>`; avoid a full terminal namespace unless it proves necessary.
- Add session behavior tied to detected project roots, with storage in XDG state paths.
- Ensure search/navigation uses root information without forcing cwd changes.
- If `mini.pick` benefits from it, treat `mini.fuzzy` as an internal implementation detail here rather than as a separate UX layer.

### Stage 8: Treesitter

- Add `nvim-treesitter`.
- Keep parser installation explicit and limited at first.
- Use it for highlighting/indent/textobject support where it clearly improves things.
- Avoid turning parser management into a giant implicit system.
- Revisit `mini.indentscope` here once tree-sitter, folding, and code-structure UX are in place.

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
- Git: `mini.git` + `mini.diff`
- Discoverability: `mini.clue`
- UI/status: mini modules first
- External tools: auto-installed by Mason from declared lists

## What This Plan Optimizes For

- A config you can fully understand and evolve yourself
- Minimal architectural magic
- Strong default UX with a small plugin surface
- Clear separation between generic editor behavior and language-specific behavior
- Native Neovim `0.12+` direction without losing practical conveniences
