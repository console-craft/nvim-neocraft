---
name: verify
description: Run this repo’s quality checks and relevant tests using the verify subagent before considering a change complete.
---

## Important

This skill should always be run using the `verify` subagent!

## Default quality checks (run these exact steps in order unless task says otherwise)

```bash
luacheck init.lua lua/ after/ # check for errors
stylua init.lua lua/ after/ # format Lua files
lua-language-server --check init.lua lua/ after/ # Type check (requires lua-language-server CLI)
```

## Expected behavior while fixing

If `stylua` changes files, that is expected. Re-run it after fixes if needed.

When a step fails, fix the issue and re-run the smallest subset that proves it’s fixed (then continue).

Before reporting “done”, ensure all default verification steps pass.

