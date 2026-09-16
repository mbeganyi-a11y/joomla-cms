#!/bin/bash
#
# Runs once when the container is created -- and, crucially, at prebuild time.
#
# Everything here is baked into the Codespaces prebuild image, so this script
# must only do work that is identical for every codespace: install
# dependencies, build assets, configure Apache. Anything that depends on the
# running codespace (its hostname) or on the database (whose volume starts
# empty in every new codespace) belongs in post-start.sh instead.

set -euo pipefail

JOOMLA_ROOT="/workspaces/joomla-cms"
cd "$JOOMLA_ROOT"

echo "--- Joomla dev environment: create-time setup ---"

git config --global --add safe.directory "$JOOMLA_ROOT"

echo "--> Installing Composer dependencies..."
composer install --no-progress

echo "--> Installing npm dependencies and building assets..."
# 'npm ci' honours package-lock.json exactly; its 'install' lifecycle script
# runs build/build.mjs --prepare, which populates media/ and
# installation/template/css. Both are required for Joomla to boot.
npm ci

echo "--> Installing the Cypress binary..."
npx cypress install

# Joomla needs AllowOverride for its .htaccess rewrite rules. Use a dedicated
# conf file rather than appending to apache2.conf, which would add a duplicate
# block every time this script runs.
echo "--> Configuring Apache..."
cat > /etc/apache2/conf-available/joomla-dev.conf <<CONF
<Directory ${JOOMLA_ROOT}>
    AllowOverride All
    Require all granted
</Directory>
CONF
a2enconf joomla-dev
a2enmod rewrite

# Cypress reads cypress.config.mjs (gitignored) -- the supported way to point
# the suite at this environment without editing tracked files.
if [ ! -f "${JOOMLA_ROOT}/cypress.config.mjs" ]; then
    echo "--> Writing cypress.config.mjs..."
    sed \
        -e "s/db_host: '[^']*'/db_host: 'mysql'/" \
        -e "s/db_user: '[^']*'/db_user: 'joomla_ut'/" \
        -e "s/db_password: '[^']*'/db_password: 'joomla_ut'/" \
        -e "s/smtp_host: '[^']*'/smtp_host: 'mailpit'/" \
        -e "s|logFile: '[^']*'|logFile: '/var/log/apache2/error.log'|" \
        cypress.config.dist.mjs > cypress.config.mjs
fi

echo "✅ Create-time setup complete."
