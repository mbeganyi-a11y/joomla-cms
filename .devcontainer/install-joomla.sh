#!/bin/bash
#
# Installs (or reinstalls) Joomla from the repository source into the dev database.
#
# Idempotent and safe to re-run: it drops and recreates the schema first, so it
# doubles as the "reset my preview to a clean site" command:
#
#     bash .devcontainer/install-joomla.sh
#
# Runs non-interactively via installation/joomla.php (see
# installation/src/Console/InstallCommand.php). Options are derived from the
# fieldsets of installation/forms/setup.xml.

set -euo pipefail

# Resolve alongside this script so it works both from the repo checkout and
# when mounted into the local preview container at /tooling.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

JOOMLA_ROOT="${JOOMLA_ROOT:-/workspaces/joomla-cms}"

DB_HOST="${DB_HOST:-mysql}"
DB_NAME="${DB_NAME:-test_joomla}"
DB_USER="${DB_USER:-joomla_ut}"
DB_PASS="${DB_PASS:-joomla_ut}"
DB_PREFIX="${DB_PREFIX:-jos_}"
DB_ROOT_PASS="${DB_ROOT_PASS:-root}"

ADMIN_USER="${ADMIN_USER:-ci-admin}"
ADMIN_REAL_NAME="${ADMIN_REAL_NAME:-jane doe}"
ADMIN_PASS="${ADMIN_PASS:-joomla-17082005}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
SITE_NAME="${SITE_NAME:-Joomla CMS Test}"

cd "$JOOMLA_ROOT"

# The CLI installer and the console app both hard-fail without built assets, so
# fail loudly here instead of half-way through the install.
if [ ! -f libraries/vendor/autoload.php ] || [ ! -d media/vendor ]; then
    echo "❌ Dependencies are missing. Run 'composer install && npm ci' first." >&2
    exit 1
fi

echo "--> Waiting for the database at ${DB_HOST}..."
until mysqladmin ping -h"$DB_HOST" --silent 2>/dev/null; do
    sleep 1
done
echo "✅ Database is ready."

# Start from a clean schema. The CLI installer creates the database itself but
# will not overwrite existing tables (the web installer's "backup/remove old
# tables" step is not available non-interactively).
echo "--> Recreating schema '${DB_NAME}'..."
mysql -h"$DB_HOST" -uroot -p"$DB_ROOT_PASS" \
    -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`; CREATE DATABASE \`${DB_NAME}\`;"

# installation/joomla.php refuses to run while a configuration.php is present.
rm -f configuration.php

echo "--> Installing Joomla from source..."
php installation/joomla.php install \
    --site-name="$SITE_NAME" \
    --admin-user="$ADMIN_REAL_NAME" \
    --admin-username="$ADMIN_USER" \
    --admin-password="$ADMIN_PASS" \
    --admin-email="$ADMIN_EMAIL" \
    --db-type="mysqli" \
    --db-host="$DB_HOST" \
    --db-name="$DB_NAME" \
    --db-user="$DB_USER" \
    --db-pass="$DB_PASS" \
    --db-prefix="$DB_PREFIX" \
    --db-encryption="0" \
    --public-folder=""

echo "--> Applying development settings..."
php cli/joomla.php config:set error_reporting=maximum
php cli/joomla.php config:set mailer=smtp
php cli/joomla.php config:set smtphost=mailpit
php cli/joomla.php config:set smtpport=1025
php cli/joomla.php config:set smtpauth=0
php cli/joomla.php config:set smtpsecure=none

# Tell Joomla its own public URL. Without this it builds links from HTTP_HOST,
# which behind the Codespaces reverse proxy is 'localhost' and breaks every
# asset and redirect. $live_site and $behind_loadbalancer are core config
# options (see installation/configuration.php-dist) -- no core patching needed.
bash "${SCRIPT_DIR}/set-live-site.sh"

# configuration.php is written 444 by the installer; the web server user needs
# to be able to rewrite it from the admin UI.
chgrp www-data configuration.php
chmod 664 configuration.php
mkdir -p images tmp administrator/logs
chgrp -R www-data images tmp administrator/logs
chmod -R g+rws images tmp administrator/logs

echo "✅ Joomla installed."
