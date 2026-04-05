# AGENTS.md

## Purpose

This repository (`filament-plugin-workbanch`) provides **shared Docker infrastructure** for developing FilamentPHP plugins. It does not contain a Laravel application or plugin code — it is a bootstrapping toolset.

The primary deliverable is `bin/workbench`: a POSIX-sh CLI that any plugin developer can use to spin up a fully working testbench environment with a single command, requiring only Docker on the host machine.

---

## Repository Structure

```
filament-plugin-workbanch/
  bin/
    workbench               ← POSIX sh CLI — the main deliverable
  docker/
    php/
      Dockerfile            ← Generic PHP 8.4-cli + Node 22 + Composer 2 image
      entrypoint.sh         ← Auto-installs vendor/ and node_modules/ on container start
  docker-compose.yml.stub   ← Template copied to plugin root by `workbench up`
  testbench.yaml.stub       ← Template copied to plugin root by `workbench up`
  README.md                 ← Developer-facing documentation
  AGENTS.md                 ← This file
```

---

## How It Is Used by Plugins

A plugin (e.g. `filament-acl`) includes this repo as a git submodule:

```
filament-acl/
  packages/
    workbench/              ← git submodule → filament-plugin-workbanch (this repo)
  workbench/                ← plugin-specific workbench code (models, seeders, etc.)
  docker-compose.yml        ← copied from stub; build.context points to packages/workbench/docker/php
  testbench.yaml            ← copied from stub; providers auto-filled from composer.json
```

The plugin's `docker-compose.yml` always points `build.context` to `./packages/workbench/docker/php`. This means the Dockerfile lives here, not in the plugin.

---

## `bin/workbench` — Architecture Rules

### Language
- **POSIX sh only** (`#!/usr/bin/env sh`, `set -eu`)
- **No bashisms**: no `[[`, no arrays, no `$BASH_SOURCE`, no `local` (where avoidable)
- Must run on `sh` (dash/busybox/bash in POSIX mode)

### Symlink resolution
`vendor/bin/workbench` is a Composer-managed symlink. The script resolves its real path using `readlink`/`realpath` to find `WORKBENCH_SOURCE` (the directory containing the stubs and Dockerfile).

### Plugin root detection
The script walks up from `$PWD` looking for a `composer.json` that is NOT this package. It uses `grep` to check the `"name"` field — no Python or PHP needed for this step.

### JSON parsing (providers detection)
Requires extracting `extra.laravel.providers` from `composer.json`. Strategy:
1. Use `python3 -c "..."` (available on 99% of Linux/macOS systems)
2. Fallback: `docker run --rm python:3-alpine python3 -c "..."`

Never add `jq` or any other tool as a runtime dependency.

### No host dependencies beyond Docker
All commands that run PHP or Composer must go through `docker compose exec` or `docker run` — never call `php`, `composer`, or `node` directly on the host.

---

## `docker/php/Dockerfile` — Rules

- Base: `php:8.4-cli-bookworm` (Debian)
- Node: multi-stage copy from `node:22-bookworm-slim`
- Composer: copied from `composer:2`
- Extensions: `intl`, `pcntl`, `zip`
- Non-root user: `workbench` (uid/gid from build args `WWWUSER`/`WWWGROUP`)
- Entrypoint: `plugin-workbench-entrypoint` (the copied `entrypoint.sh`)

Do not add plugin-specific extensions. If a plugin needs extra PHP extensions, it should override the Dockerfile or open an issue.

---

## `docker/php/entrypoint.sh` — Rules

- Runs `composer install` if `vendor/autoload.php` is missing or stale
- Runs `npm install` if `package.json` exists and `node_modules/` is missing
- Ends with `exec "$@"` — always passes control to the CMD

Do not add plugin-specific logic here. Keep it generic.

---

## Stubs — Rules

### `docker-compose.yml.stub`
- `build.context` must always point to `./packages/workbench/docker/php`
- Comments must explain all available `.env` variables
- Must list both HTTPS and SSH installation instructions in the comment header

### `testbench.yaml.stub`
- Must document the difference between `:memory:` (tests) and a file path (workbench serve)
- Provider line must use the exact pattern `# - Vendor\YourPlugin\...` so `_fill_providers()` can replace it via regex

---

## Adding a New Subcommand

1. Add a `cmd_<name>()` function in `bin/workbench`
2. Add a `<name>)  cmd_<name> ;;` case in the entry-point `case` block
3. Add a help line in `cmd_help()`
4. Update `README.md` commands table
5. Run `sh -n bin/workbench` to validate POSIX sh syntax

---

## Testing Changes

Before committing:

```bash
# Syntax check (no bash needed)
sh -n bin/workbench

# Functional test using the filament-acl plugin as reference
cd /path/to/filament-acl
git submodule update --remote packages/workbench
./packages/workbench/bin/workbench down
./packages/workbench/bin/workbench up
# → Container must start and serve http://localhost:8001/admin
```

---

## What Belongs Here vs. In the Plugin

| Item | Here | In the plugin |
|---|---|---|
| `Dockerfile` | ✅ | ❌ |
| `entrypoint.sh` | ✅ | ❌ |
| `docker-compose.yml` (generated) | Stub only | ✅ |
| `testbench.yaml` (generated) | Stub only | ✅ |
| `workbench/` app (models, seeders) | ❌ | ✅ |
| `composer.json` scripts | ❌ | ✅ |
| Plugin-specific PHP logic | ❌ | ✅ |
