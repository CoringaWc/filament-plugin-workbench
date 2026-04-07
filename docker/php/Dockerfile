FROM php:8.4-cli-bookworm@sha256:15bd32b1c20ec9bb8edd09849745b5345105001b9780c873af7adae4e5d0cf54

ARG WWWUSER=1000
ARG WWWGROUP=1000

# Node.js 22.22.2 — installed from official tarball (SHA256-verified) to avoid
# any base-image vulnerability scanner false positives from FROM node:* stages.
# CVE-2026-33671: picomatch bundled in npm 10.9.7 is patched to 4.0.4 in the
# same RUN layer so it is never present in any image layer.
ARG NODE_VERSION=22.22.2
ARG NODE_SHA256=88fd1ce767091fd8d4a99fdb2356e98c819f93f3b1f8663853a2dee9b438068a

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        libicu-dev \
        libzip-dev \
        unzip \
        xz-utils \
        zip \
    && docker-php-ext-install -j"$(nproc)" \
        intl \
        pcntl \
        zip \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
        -o /tmp/node.tar.xz \
    && echo "${NODE_SHA256}  /tmp/node.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && cd /tmp && npm pack picomatch@4.0.4 --quiet \
    && tar xf /tmp/picomatch-4.0.4.tgz -C /tmp \
    && cp -a /tmp/package/. /usr/local/lib/node_modules/npm/node_modules/picomatch/ \
    && rm -rf /tmp/picomatch-4.0.4.tgz /tmp/package \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g "${WWWGROUP}" workbench \
    && useradd --no-log-init -u "${WWWUSER}" -g "${WWWGROUP}" -m workbench \
    && mkdir -p /tmp/composer/cache /tmp/.npm /tmp/.cache \
    && chown -R "${WWWUSER}:${WWWGROUP}" /tmp/composer /tmp/.npm /tmp/.cache

WORKDIR /var/www/html

COPY --chmod=755 entrypoint.sh /usr/local/bin/plugin-workbench-entrypoint

ENTRYPOINT ["plugin-workbench-entrypoint"]
