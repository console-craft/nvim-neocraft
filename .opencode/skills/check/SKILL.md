---
name: verify
description: Run this repo’s quality checks and relevant tests using the verify subagent before considering a change complete.
---

## Important

This skill should always be run using the `verify` subagent!

## Default quality checks (run this exact command unless task says otherwise)

```bash
./scripts/checks.sh
```

## Expected behavior while fixing

`./scripts/checks.sh` runs `stylua`, `luacheck`, `lua-language-server --check`, and a headless live `lua_ls` runtime diagnostics pass.

If `stylua` changes files, that is expected. Re-run `./scripts/checks.sh` after fixes if needed.

When a step fails, fix the issue and re-run the smallest subset that proves it’s fixed (then continue).

Before reporting “done”, ensure all default verification steps pass.
