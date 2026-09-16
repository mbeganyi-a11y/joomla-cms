#!/bin/bash
#
# Runs on every container start, including the first start of a codespace
# created from a prebuild image.
#
# This is where anything codespace-specific has to live:
#   * Apache is not running yet (the app service's command is 'sleep infinity')
#   * the mysql volume is empty in a brand new codespace, even from a prebuild
#   * $live_site depends on $CODESPACE_NAME, which is different every time

set -euo pipefail

JOOMLA_ROOT="/workspaces/joomla-cms"
cd "$JOOMLA_ROOT"

echo "--- Joomla dev environment: start-time setup ---"

service apache2 start

echo "--> Waiting for the database..."
until mysqladmin ping -h mysql --silent 2>/dev/null; do
    sleep 1
done

# Install only if this is a fresh database. A prebuilt image may already carry
# a configuration.php from create time while the database volume is empty, so
# the table check -- not the config file -- is what decides.
if mysql -hmysql -ujoomla_ut -pjoomla_ut test_joomla \
        -e "SELECT 1 FROM jos_users LIMIT 1;" >/dev/null 2>&1; then
    echo "✅ Existing Joomla installation found."
    PREVIEW_URL=$(bash "${JOOMLA_ROOT}/.devcontainer/set-live-site.sh")
else
    echo "--> No installation found, installing Joomla..."
    bash "${JOOMLA_ROOT}/.devcontainer/install-joomla.sh"
    PREVIEW_URL=$(bash "${JOOMLA_ROOT}/.devcontainer/set-live-site.sh")
fi

DETAILS_FILE="${JOOMLA_ROOT}/codespace-details.txt"
{
    echo ""
    echo "---"
    echo "🚀 Joomla preview environment is ready"
    echo ""
    echo "  Site:        ${PREVIEW_URL}"
    echo "  Admin:       ${PREVIEW_URL}/administrator"
    echo "  Username:    ci-admin"
    echo "  Password:    joomla-17082005"
    echo ""
    echo "  phpMyAdmin:  port 8081  (user joomla_ut / joomla_ut)"
    echo "  Mailpit:     port 8025  (all outgoing mail lands here)"
    echo ""
    echo "Screen reader testing: open the Site URL above in your own browser"
    echo "(Chrome/Firefox on your machine) and drive it with NVDA/JAWS/VoiceOver."
    echo "The screen reader reads your browser's accessibility tree, so it does"
    echo "not matter that the server runs in the cloud."
    echo ""
    echo "To share the URL with someone who has no access to this codespace,"
    echo "open the Ports tab, right-click port 443 -> Port Visibility -> Public."
    echo ""
    echo "Reset to a clean site:  bash .devcontainer/install-joomla.sh"
    echo "Run system tests:       npx cypress run --config-file cypress.config.mjs"
    echo "  (note: the install/ specs reinstall the site by design -- re-run"
    echo "   install-joomla.sh afterwards to get this environment back)"
    echo "---"
} | tee "$DETAILS_FILE"
