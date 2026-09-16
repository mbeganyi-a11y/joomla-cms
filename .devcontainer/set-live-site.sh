#!/bin/bash
#
# Points Joomla's $live_site at whatever URL this environment is reachable on.
#
# Must run on every container start, not just on create: the Codespaces
# forwarding hostname is derived from $CODESPACE_NAME, which differs for every
# codespace, so a value baked into a prebuild image would be wrong.
#
# Echoes the resolved URL on stdout.

set -euo pipefail

JOOMLA_ROOT="${JOOMLA_ROOT:-/workspaces/joomla-cms}"
cd "$JOOMLA_ROOT"

if [ -n "${PREVIEW_URL:-}" ]; then
    : # explicit override wins (used by the local docker stack)
elif [ -n "${CODESPACE_NAME:-}" ]; then
    # Codespaces forwards each port on <codespace>-<port>.<domain>, always HTTPS.
    PREVIEW_URL="https://${CODESPACE_NAME}-443.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
else
    # Plain local devcontainer: Apache is published on 443 of the host.
    PREVIEW_URL="https://localhost"
fi

if [ -f configuration.php ]; then
    # Without this, Joomla builds every URL from HTTP_HOST, which behind a
    # reverse proxy is 'localhost' -- breaking all assets and redirects.
    php cli/joomla.php config:set live_site="$PREVIEW_URL" >/dev/null

    # 'config:set' validates keys against the configuration file it already
    # has, and behind_loadbalancer is not among the keys the installer writes
    # (see installation/src/Model/ConfigurationModel.php::createConfiguration),
    # so it would be rejected as unknown. Add the property directly. It makes
    # Joomla trust X-Forwarded-Proto, which is how the Codespaces proxy tells
    # it the client spoke HTTPS while the request arrived over plain HTTP.
    php -r '
        $file = "configuration.php";
        $source = file_get_contents($file);
        if (strpos($source, "behind_loadbalancer") === false) {
            $patched = preg_replace(
                "/\}\s*$/",
                "\tpublic \$behind_loadbalancer = true;\n}\n",
                $source,
                1
            );
            if ($patched !== null && $patched !== $source) {
                file_put_contents($file, $patched);
            }
        }
    '
    # Never leave a syntactically broken configuration behind.
    php -l configuration.php >/dev/null
fi

echo "$PREVIEW_URL"
