#!/usr/bin/env sh

set -eu

if [ ! -f vendor/autoload.php ] || [ composer.lock -nt vendor/autoload.php ]; then
    composer install --no-interaction --prefer-dist
fi

if [ -f package.json ] && [ ! -d node_modules ]; then
    npm install
fi

exec "$@"
