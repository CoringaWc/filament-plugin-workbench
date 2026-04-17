# filament-plugin-workbench

Shared development environment infrastructure for FilamentPHP plugins.

Provides:

- **Generic Dockerfile** (PHP 8.4 + Node 22 + Composer 2)
- **Entrypoint** with automatic dependency installation
- **Templates** for `docker-compose.yml` and `testbench.yaml`
- **`workbench` CLI** to start, stop, and manage the environment with a single command
- **`sail` CLI** — Sail-like wrapper to run artisan, phpunit, phpstan, pint, and other commands inside the container

> **Only prerequisite: Docker installed.** No PHP, Composer, or Node required on the host.

---

## Installation

### Via git submodule (recommended)

Requires only `git` and `docker`.

```bash
# 1. Add the submodule to the plugin repository
git submodule add https://github.com/CoringaWc/filament-plugin-workbench.git packages/workbench
git submodule update --init --recursive

# 2. Start the environment (copies templates, detects providers, starts container)
./packages/workbench/bin/workbench up
```

When running `workbench up`, the script:

- Copies `docker-compose.yml` from the template (if it does not exist yet)
- Copies `testbench.yaml` from the template (if it does not exist yet) and fills providers from `composer.json`
- Always verifies that all providers and scripts in `composer.json` are configured
- Builds the Docker image and starts the container
- Follows container logs in real time (use `-d` to run in the background)

---

### Via Composer

Use when the plugin already has Composer as its primary workflow.

```bash
# 1. Install the package via Docker (no Composer needed on the host)
docker run --rm -v "$(pwd):/app" -w /app composer:2 require --dev --ignore-platform-req=ext-intl coringawc/filament-plugin-workbench

# 2. Start the environment
./vendor/bin/workbench up
```

> **Note:** running `workbench up` or `workbench install` automatically adds the `bootstrap:workbench`, `serve`, and `fresh:workbench` scripts to the plugin's `composer.json` if they are not already present.

---

## File permissions

The container runs as a non-root user (`workbench`) with the same UID/GID as the host user — so files created inside the container (screenshots, test results, generated code) are owned by your host user with no `sudo` needed.

The default UID/GID is `1000`. If your host user has a different UID (run `id -u` to check), create a `.env` file in the plugin root before the first `workbench up`:

```bash
echo "WWWUSER=$(id -u)" >> .env
echo "WWWGROUP=$(id -g)" >> .env
```

These values are read by `docker-compose.yml` and passed as build arguments to the image. If you skip this step on a non-`1000` host and find that generated files are owned by the wrong user, remove the existing image and volume, add the `.env`, and run `workbench up` again:

```bash
docker compose down --volumes --rmi local
./vendor/bin/workbench up   # or ./packages/workbench/bin/workbench up
```

The generated `docker-compose.yml` also injects `DB_DATABASE` with a persistent SQLite path inside the container by default:

```bash
DB_DATABASE=/var/www/html/vendor/orchestra/testbench-core/laravel/database/database.sqlite
```

This avoids Testbench falling back to the `testing` in-memory connection during HTTP requests handled by `vendor/bin/testbench serve`.

---

## Available commands

| Command                     | Description                                                                              |
| --------------------------- | ---------------------------------------------------------------------------------------- |
| `workbench up`              | Copy templates if needed, verify providers, inject scripts, start container, follow logs |
| `workbench up -d`           | Same as `up`, but starts in detached mode (does not block the terminal)                  |
| `workbench install`         | Copy templates, fill providers, inject scripts into `composer.json` (no container start) |
| `workbench install --force` | Same as `install`, overwrites existing files without prompting                           |
| `workbench down`            | Stop and remove the container                                                            |
| `workbench fresh`           | Run `migrate:fresh --seed` inside the container                                          |
| `workbench logs`            | Follow container logs in real time                                                       |
| `workbench shell`           | Open an interactive shell inside the container                                           |
| `workbench help`            | Show help                                                                                |

---

## `sail` — Day-to-Day Development CLI

While `workbench` handles environment **lifecycle** (up/down/install), `sail` is a **Sail-like proxy** for running commands inside the already-running container. Available at `vendor/bin/sail` when installed via Composer.

### Usage

```bash
./vendor/bin/sail <command> [arguments]
```

### Commands

| Command                             | Description                             |
| ----------------------------------- | --------------------------------------- |
| `sail artisan <cmd>`                | Run a testbench artisan command         |
| `sail phpunit [args]` / `sail test` | Run PHPUnit tests                       |
| `sail phpstan [args]`               | Run PHPStan analysis                    |
| `sail pint [args]` / `sail lint`    | Run Laravel Pint                        |
| `sail rector [args]`                | Run Rector                              |
| `sail composer [args]`              | Run Composer                            |
| `sail php [args]`                   | Run PHP directly                        |
| `sail node [args]`                  | Run Node.js                             |
| `sail npm [args]`                   | Run npm                                 |
| `sail shell`                        | Open a bash shell in the container      |
| `sail up`                           | Start the Docker containers             |
| `sail down`                         | Stop the Docker containers              |
| `sail build`                        | Build the Docker containers             |
| `sail logs`                         | Tail container logs                     |
| `sail <anything>`                   | Passed through to `docker compose exec` |

### Examples

```bash
# Artisan commands via testbench
./vendor/bin/sail artisan migrate:fresh --seed
./vendor/bin/sail artisan tinker

# Testing & quality
./vendor/bin/sail phpunit --testdox
./vendor/bin/sail phpstan --memory-limit=1G
./vendor/bin/sail pint --dirty

# Composer & shell
./vendor/bin/sail composer install
./vendor/bin/sail shell
```

---

## Generating documentation screenshots

The workbench environment is pre-configured for Playwright screenshot generation. The PHP image includes all Chromium system libraries, and the Playwright browser binary is installed automatically on first container start when `@playwright/test` is listed as a dependency in the plugin's `package.json`.

### Setup

Add `@playwright/test` to the plugin's `package.json`:

```json
{
    "scripts": {
        "screenshots": "npx playwright test workbench/tmp-screenshots.spec.js"
    },
    "devDependencies": {
        "@playwright/test": "^1.59.1"
    }
}
```

Create `workbench/tmp-screenshots.spec.js` with your Playwright test. On the next container start, the Chromium browser is downloaded to the `playwright-browsers` Docker volume — subsequent starts skip the download.

### Running screenshots

```bash
docker compose exec php npm run screenshots
```

### How it works

- **System libraries** — all Chromium shared libraries (`libglib2.0-0`, `libnss3`, `libpangocairo`, `libgbm1`, etc.) are baked into the Docker image — no manual `apt-get` needed.
- **Browser binary** — installed on first container start via the entrypoint, using the exact version bundled with the project's `@playwright/test` package.
- **Persistent cache** — the `playwright-browsers` named Docker volume mounts at `/tmp/.cache/ms-playwright`, so the 110 MB Chromium binary is downloaded only once per host machine.

---

## Adding to a new plugin

```bash
# In the new plugin repository:
git submodule add https://github.com/CoringaWc/filament-plugin-workbench.git packages/workbench
git submodule update --init --recursive

# Start the environment
./packages/workbench/bin/workbench up
```

The script automatically detects `ServiceProvider`s declared in `composer.json`
(`extra.laravel.providers`) and fills the generated `testbench.yaml`.

The scripts `bootstrap:workbench`, `serve`, and `fresh:workbench` are automatically added
to the plugin's `composer.json` by `workbench up` or `workbench install` if they are missing.

The generated `docker-compose.yml` also includes a default persistent SQLite path for the Testbench skeleton database so that `workbench up` produces a container-ready environment without extra manual configuration.

After that, the plugin structure will look like:

```
my-plugin/
  packages/
    workbench/          ← this submodule
  workbench/            ← plugin-specific workbench code (models, seeders, etc.)
  docker-compose.yml    ← generated by workbench up (build.context resolved dynamically)
  testbench.yaml        ← generated by workbench up (providers filled automatically)
  composer.json         ← scripts: bootstrap:workbench, serve, fresh:workbench
```

---

## What belongs where

| File / Folder                   | Location                                        | Why                                                          |
| ------------------------------- | ----------------------------------------------- | ------------------------------------------------------------ |
| `Dockerfile`, `entrypoint.sh`   | **This package** (`packages/workbench/docker/`) | Generic, reusable infrastructure                             |
| `stubs/docker-compose.yml.stub` | **This package**                                | Template with `build.context` placeholder (resolved at copy) |
| `stubs/testbench.yaml.stub`     | **This package**                                | Template with common variables documented                    |
| `bin/workbench`                 | **This package**                                | Bootstrapping CLI                                            |
| `bin/sail`                      | **This package**                                | Sail-like development proxy CLI                              |
| `workbench/`                    | **In the plugin**                               | Plugin-specific models, seeders, policies, resources, etc.   |
| `composer.json`                 | **In the plugin**                               | Scripts `bootstrap:workbench`, `serve`, `fresh:workbench`    |
| `testbench.yaml`                | **In the plugin**                               | Plugin-specific providers and env                            |
| `docker-compose.yml`            | **In the plugin**                               | Generated by `workbench up` — can be customised              |

---

## Updating to the latest version

### Via git submodule

```bash
git submodule update --remote packages/workbench
git add packages/workbench
git commit -m "chore: bump filament-plugin-workbench"
```

### Via Composer

```bash
# If Composer is available locally:
composer update coringawc/filament-plugin-workbench

# If using Docker (no Composer on host):
docker run --rm -v "$(pwd):/app" -w /app composer:2 update --ignore-platform-req=ext-intl coringawc/filament-plugin-workbench
```

---

## Package structure

```
filament-plugin-workbench/
  bin/
    sail                    ← Sail-like CLI for day-to-day commands (bash, artisan/phpunit/pint proxy)
    workbench               ← CLI (POSIX sh, requires only Docker on the host)
  docker/
    php/
      Dockerfile            ← PHP 8.4-cli + Node 22 + Composer 2, non-root user
      entrypoint.sh         ← auto-installs vendor/ and node_modules/ on startup
  stubs/
    docker-compose.yml.stub ← docker-compose.yml template for plugins
    testbench.yaml.stub     ← testbench.yaml template for plugins
```
