# AGENTS.md

## Purpose

This repository (`filament-plugin-workbench`) provides **shared Docker infrastructure** for developing FilamentPHP plugins. It does not contain a Laravel application or plugin code — it is a bootstrapping toolset.

The primary deliverables are:

- `bin/workbench`: a POSIX-sh CLI for environment lifecycle (up/down/install/fresh/logs/shell), requiring only Docker on the host
- `bin/sail`: a Bash CLI for day-to-day development commands (artisan/phpunit/phpstan/pint/composer/php/node/npm), proxying them into the running Docker container — similar to Laravel Sail

---

## Repository Structure

```
filament-plugin-workbench/
  bin/
    sail                    ← Bash CLI — Sail-like proxy for development commands
    workbench               ← POSIX sh CLI — the environment lifecycle tool
  docker/
    php/
      Dockerfile            ← Generic PHP 8.4-cli + Node 22 + Composer 2 image
      entrypoint.sh         ← Auto-installs vendor/ and node_modules/ on container start
  stubs/
    docker-compose.yml.stub ← Template copied to plugin root by `workbench up`
    testbench.yaml.stub     ← Template copied to plugin root by `workbench up`
  README.md                 ← Developer-facing documentation
  AGENTS.md                 ← This file
```

---

## How It Is Used by Plugins

A plugin (e.g. `filament-acl`) includes this repo as a git submodule:

```
filament-acl/
  packages/
    workbench/              ← git submodule → filament-plugin-workbench (this repo)
  workbench/                ← plugin-specific workbench code (models, seeders, etc.)
  docker-compose.yml        ← copied from stub; build.context resolved dynamically
  testbench.yaml            ← copied from stub; providers auto-filled from composer.json
```

The plugin's `docker-compose.yml` has its `build.context` resolved dynamically by `_fix_docker_context()`:

- **Submodule install** → `./packages/workbench/docker/php`
- **Composer install** → `./vendor/coringawc/filament-plugin-workbench/docker/php`

This means the Dockerfile lives in this package, not in the plugin.

---

## `bin/workbench` — Architecture Rules

### Language

- **POSIX sh only** (`#!/usr/bin/env sh`, `set -eu`)
- **No bashisms**: no `[[`, no arrays, no `$BASH_SOURCE`, no `local` (where avoidable)
- Must run on `sh` (dash/busybox/bash in POSIX mode)

### Symlink resolution

`vendor/bin/workbench` is a Composer-managed symlink. The script resolves its real path using `readlink`/`realpath` to find `WORKBENCH_SOURCE` (the package root directory; stubs live in `stubs/` and the Dockerfile in `docker/`).

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
- Chromium system libraries: `libglib2.0-0`, `libnss3`, `libnspr4`, `libdbus-1-3`, `libatk1.0-0`, `libatk-bridge2.0-0`, `libcups2`, `libxcb1`, `libxkbcommon0`, `libxcomposite1`, `libxdamage1`, `libxfixes3`, `libxrandr2`, `libgbm1`, `libpangocairo-1.0-0`, `libasound2` — installed in a separate `RUN` block so they do not pollute the Node/PHP install layer cache.
- Non-root user: `workbench` (uid/gid from build args `WWWUSER`/`WWWGROUP`)
- Entrypoint: `plugin-workbench-entrypoint` (the copied `entrypoint.sh`)
- **Volume ownership:** The Dockerfile must `mkdir -p /tmp/.cache/ms-playwright` within the same `RUN` block that runs `chown -R workbench:workbench /tmp/.cache`. Docker named volumes are initialized from the image's directory tree on first use — if `ms-playwright` does not already exist in the image when the volume is first mounted, Docker creates it as `root:root`, which prevents the non-root `workbench` user from writing to it. This pre-creation ensures the volume inherits correct ownership.

Do not add plugin-specific extensions. If a plugin needs extra PHP extensions, it should override the Dockerfile or open an issue.

The Chromium system libraries are intentionally included in the base image even when a plugin does not use Playwright — the total overhead is ~20 MB and avoids any manual `apt-get` step for users who add screenshot generation to their plugin.

---

## `docker/php/entrypoint.sh` — Rules

- Runs `composer install` if `vendor/autoload.php` is missing or stale
- Runs `npm install` if `package.json` exists and `node_modules/` is missing
- Installs the Playwright Chromium browser if `@playwright/test` is in `package.json` and the browser cache (`$XDG_CACHE_HOME/ms-playwright`) is empty. Uses `ls -A` to detect empty vs. populated volume mount. The browser binary is stored in a named Docker volume (`playwright-browsers`) so it survives container restarts without re-downloading. **Important:** this relies on `ms-playwright` being pre-created in the Dockerfile with `workbench` ownership — see the Dockerfile volume ownership note above.
- Ends with `exec "$@"` — always passes control to the CMD

Do not add plugin-specific logic here. Keep it generic.

---

## Stubs — Rules

### `docker-compose.yml.stub`

- `build.context` uses the placeholder `__WORKBENCH_DOCKER_CONTEXT__` — resolved dynamically by `_fix_docker_context()` at copy time
- Comments must explain all available `.env` variables
- Must list Composer, HTTPS submodule, and SSH submodule installation instructions in the comment header
- Must declare the `playwright-browsers` named volume mounted at `/tmp/.cache/ms-playwright` and set `PLAYWRIGHT_BROWSERS_PATH` environment variable accordingly — these are required for the automatic Playwright browser install in `entrypoint.sh` to cache correctly

### `testbench.yaml.stub`

- Must document the difference between `:memory:` (tests) and a file path (workbench serve)
- Provider line must use the exact pattern `# - Vendor\YourPlugin\...` so `_ensure_providers()` can replace it via regex

---

## `bin/sail` — Architecture Rules

### Language

- **Bash** (`#!/usr/bin/env bash`, `set -euo pipefail`)
- Uses `$BASH_SOURCE` for symlink resolution (Composer creates symlinks at `vendor/bin/sail`)

### Purpose separation

- `bin/workbench` = **environment lifecycle** (up/down/install/fresh/logs/shell) — POSIX sh, works without a running container
- `bin/sail` = **development proxy** (artisan/phpunit/phpstan/pint/composer/php/node/npm) — Bash, requires a running container

### Plugin root detection

Resolves symlinks first (handles `vendor/bin/sail → ../../bin/sail`), then walks up from the resolved path to find `docker-compose.yml`.

### TTY handling

Detects terminal with `[ -t 0 ]` and passes `-it` or `-T` accordingly to `docker compose exec`.

### Command dispatch

| Category         | Commands                        | Target                                 |
| ---------------- | ------------------------------- | -------------------------------------- |
| Artisan          | `artisan`                       | `php vendor/bin/testbench <args>`      |
| Testing          | `phpunit`, `test`               | `vendor/bin/phpunit <args>`            |
| Analysis         | `phpstan`, `analyse`, `analyze` | `vendor/bin/phpstan analyse <args>`    |
| Style            | `pint`, `lint`                  | `vendor/bin/pint <args>`               |
| Refactoring      | `rector`                        | `vendor/bin/rector <args>`             |
| Composer         | `composer`                      | `composer <args>`                      |
| PHP              | `php`                           | `php <args>`                           |
| Node             | `node`, `npm`                   | `node <args>` / `npm <args>`           |
| Shell            | `shell`, `bash`                 | `bash`                                 |
| Docker lifecycle | `up`, `down`, `build`, `logs`   | `docker compose <cmd>`                 |
| Passthrough      | anything else                   | `docker compose exec php <cmd> <args>` |

### No host dependencies beyond Docker

Same principle as `bin/workbench`: all commands run through `docker compose exec`.

---

## Adding a New Subcommand

### For `bin/workbench` (POSIX sh)

1. Add a `cmd_<name>()` function in `bin/workbench`
2. Add a `<name>)  cmd_<name> "$@" ;;` case in the entry-point `case` block (pass `"$@"` if the command accepts options)
3. Add a help line in `cmd_help()`
4. Update `README.md` commands table
5. Run `sh -n bin/workbench` to validate POSIX sh syntax

### For `bin/sail` (Bash)

1. Add a new `case` entry in the command dispatch block
2. Update the help output in the `[ $# -eq 0 ]` block
3. Update `README.md` sail commands table
4. Run `bash -n bin/sail` to validate syntax

---

## Subcommand Reference

### `up [-d]`

Silently copies `docker-compose.yml` and `testbench.yaml` from stubs (skips without prompting if they already exist), then calls `_ensure_providers` and `_ensure_composer_scripts`, and finally starts the container via `docker compose up --build -d`.

- `-d` / `--detach`: skips log tailing after container start.

### `install [-f/--force]`

Copies `docker-compose.yml` and `testbench.yaml` from stubs with interactive overwrite prompt (or silently overwrites with `--force`), then calls `_ensure_providers` and `_ensure_composer_scripts`. Does **not** start the container.

- `-f` / `--force`: overwrites existing files without prompting.

### `down`

Runs `docker compose down` in the plugin root.

### `fresh`

Runs `composer run fresh:workbench` inside the container (migrate:fresh --seed).

### `logs`

Tails container logs: `docker compose logs -f php`.

### `shell`

Opens an interactive shell in the container: `docker compose exec php sh`.

### `help`

Prints usage information.

---

## Helper Function Reference

### `_ensure_providers(testbench_yaml, composer_json)`

Replaces `_fill_providers`. Always reads `extra.laravel.providers` from `composer.json` and:

- If the `# - Vendor` placeholder block is present: replaces it with actual provider lines.
- If providers are already listed: checks for missing ones and inserts them.
- If no providers exist in `composer.json`: emits a `_warn` and returns (no crash).
- Also generates `APP_KEY` if the `REPLACE_WITH_GENERATED_KEY` placeholder is present.

### `_ensure_composer_scripts(composer_json)`

Injects `bootstrap:workbench`, `serve`, and `fresh:workbench` scripts into the plugin's `composer.json` if they are not already present. Uses `python3` (fallback: Docker) with `json.load/dump` at `indent=4`.

### `_copy_stub(src, dest, label, force=0)`

Copies a stub file to `dest`. If `dest` exists and `force=0`, prompts the user. If `force=1`, overwrites silently.

### `_copy_stub_silent(src, dest, label)`

Copies a stub file to `dest`. If `dest` already exists, prints `"$label already exists — skipping."` and returns 1 without prompting.

### `_fix_docker_context(compose_file, plugin_root)`

Replaces the `__WORKBENCH_DOCKER_CONTEXT__` placeholder in the generated `docker-compose.yml` with the real relative path from the plugin root to `$WORKBENCH_SOURCE/docker/php`. Uses `python3 os.path.relpath` (fallback: `realpath --relative-to`, last resort: known path heuristics).

---

## Testing Changes

Before committing:

```bash
# Syntax check
sh -n bin/workbench    # POSIX sh
bash -n bin/sail       # Bash

# Functional test using the filament-acl plugin as reference
cd /path/to/filament-acl
./vendor/bin/workbench down
./vendor/bin/workbench up
# → Container must start and serve http://localhost:8001/admin

# Test sail commands
./vendor/bin/sail artisan --version
./vendor/bin/sail phpunit --no-progress
./vendor/bin/sail phpstan --memory-limit=1G
./vendor/bin/sail pint --test
```

---

## What Belongs Here vs. In the Plugin

| Item                               | Here                                | In the plugin  |
| ---------------------------------- | ----------------------------------- | -------------- |
| `Dockerfile`                       | ✅                                  | ❌             |
| `entrypoint.sh`                    | ✅                                  | ❌             |
| `bin/workbench` (lifecycle CLI)    | ✅                                  | ❌             |
| `bin/sail` (development proxy)     | ✅                                  | ❌             |
| `docker-compose.yml` (generated)   | Stub only                           | ✅             |
| `testbench.yaml` (generated)       | Stub only                           | ✅             |
| `workbench/` app (models, seeders) | ❌                                  | ✅             |
| `composer.json` scripts            | Automatically injected by workbench | ✅ (generated) |
| Plugin-specific PHP logic          | ❌                                  | ✅             |
