#!/usr/bin/env sh

set -eu

if [ ! -f vendor/autoload.php ] || [ ! -f composer.lock ] || [ composer.lock -nt vendor/autoload.php ]; then
    composer install --no-interaction --prefer-dist
fi

if [ -f package.json ] && [ ! -d node_modules ]; then
    npm install
fi

# Install the Playwright Chromium browser if @playwright/test is a dependency.
# The browser binary is cached in $XDG_CACHE_HOME/ms-playwright (backed by a
# named Docker volume so it survives container restarts without re-downloading).
# The install is skipped when the cache directory already contains files.
if [ -f package.json ] && grep -q '"@playwright/test"' package.json; then
    PLAYWRIGHT_CACHE="${XDG_CACHE_HOME:-/tmp/.cache}/ms-playwright"
    if [ -z "$(ls -A "$PLAYWRIGHT_CACHE" 2>/dev/null)" ]; then
        echo "Installing Playwright Chromium browser..."
        npx playwright install chromium
    fi
fi

exec "$@"
