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

## Available commands

| Command                     | Description                                                                                    |
| --------------------------- | ---------------------------------------------------------------------------------------------- |
| `workbench up`              | Copy templates if needed, verify providers, inject scripts, start container, follow logs       |
| `workbench up -d`           | Same as `up`, but starts in detached mode (does not block the terminal)                        |
| `workbench install`         | Copy templates, fill providers, inject scripts into `composer.json` (no container start)       |
| `workbench install --force` | Same as `install`, overwrites existing files without prompting                                 |
| `workbench down`            | Stop and remove the container                                                                  |
| `workbench fresh`           | Run `migrate:fresh --seed` inside the container                                                |
| `workbench logs`            | Follow container logs in real time                                                             |
| `workbench shell`           | Open an interactive shell inside the container                                                 |
| `workbench help`            | Show help                                                                                      |

---

## `sail` — Day-to-Day Development CLI

While `workbench` handles environment **lifecycle** (up/down/install), `sail` is a **Sail-like proxy** for running commands inside the already-running container. Available at `vendor/bin/sail` when installed via Composer.

### Usage

```bash
./vendor/bin/sail <command> [arguments]
```

### Commands

| Command                            | Description                                            |
| ---------------------------------- | ------------------------------------------------------ |
| `sail artisan <cmd>`               | Run a testbench artisan command                        |
| `sail phpunit [args]` / `sail test`| Run PHPUnit tests                                      |
| `sail phpstan [args]`              | Run PHPStan analysis                                   |
| `sail pint [args]` / `sail lint`   | Run Laravel Pint                                       |
| `sail rector [args]`               | Run Rector                                             |
| `sail composer [args]`             | Run Composer                                           |
| `sail php [args]`                  | Run PHP directly                                       |
| `sail node [args]`                 | Run Node.js                                            |
| `sail npm [args]`                  | Run npm                                                |
| `sail shell`                       | Open a bash shell in the container                     |
| `sail up`                          | Start the Docker containers                            |
| `sail down`                        | Stop the Docker containers                             |
| `sail build`                       | Build the Docker containers                            |
| `sail logs`                        | Tail container logs                                    |
| `sail <anything>`                  | Passed through to `docker compose exec`                |

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

| File / Folder                 | Location                                       | Why                                                          |
| ----------------------------- | ---------------------------------------------- | ------------------------------------------------------------ |
| `Dockerfile`, `entrypoint.sh` | **This package** (`packages/workbench/docker/`)| Generic, reusable infrastructure                             |
| `stubs/docker-compose.yml.stub` | **This package**                             | Template with `build.context` placeholder (resolved at copy) |
| `stubs/testbench.yaml.stub`    | **This package**                             | Template with common variables documented                    |
| `bin/workbench`               | **This package**                               | Bootstrapping CLI                                            |
| `bin/sail`                    | **This package**                               | Sail-like development proxy CLI                              |
| `workbench/`                  | **In the plugin**                              | Plugin-specific models, seeders, policies, resources, etc.   |
| `composer.json`               | **In the plugin**                              | Scripts `bootstrap:workbench`, `serve`, `fresh:workbench`    |
| `testbench.yaml`              | **In the plugin**                              | Plugin-specific providers and env                            |
| `docker-compose.yml`          | **In the plugin**                              | Generated by `workbench up` — can be customised              |

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
