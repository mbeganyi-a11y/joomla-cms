# How to deploy a Joomla preview

From nothing to a working URL. Copy-paste, no theory.

Two paths. Pick one:

- **Cloud** — you get an HTTPS URL you can share. Needs a browser and push access.
- **Local** — you get `http://localhost:8100`. Needs Docker. Works offline.

---

## If you only read three lines

```bash
git clone git@github.com:mbeganyi-a11y/joomla-cms.git && cd joomla-cms
git checkout tooling/preview && bin/preview-setup
bin/preview cloud 5.4-dev          # or: bin/preview up 5.4-dev
```

Login for every preview: **`ci-admin` / `joomla-17082005`**

---

## Path 1 — Cloud (Codespaces)

### One-time setup

```bash
git clone git@github.com:mbeganyi-a11y/joomla-cms.git
cd joomla-cms
git checkout tooling/preview
bin/preview-setup
```

`bin/preview-setup` adds the `upstream` remote and writes local ignore rules.
It does not modify any tracked file.

### Deploy

```bash
git push origin my-branch        # the branch must exist on the fork
bin/preview cloud my-branch
```

Output ends with a link like:

```
https://codespaces.new/mbeganyi-a11y/joomla-cms/tree/preview/my-branch
```

Open it. GitHub builds a container, installs dependencies, installs Joomla, and
starts Apache. **First boot takes several minutes** — that is `composer install`
plus `npm ci` plus the asset build. It is not hung.

When it finishes, the terminal prints the site URL, the admin URL and the
credentials. They are also written to `codespace-details.txt`.

### Use it

Open the site URL **in your own browser** — not in the codespace's built-in
preview pane. Then drive it with NVDA/JAWS/VoiceOver normally. The screen reader
reads your local browser's accessibility tree; the server being remote is
irrelevant.

Ports inside the codespace: **443** site, **8081** phpMyAdmin, **8025** Mailpit
(every mail Joomla sends lands there instead of being delivered).

### Share the URL

The forwarded port is private by default, which is fine for you. To let someone
else open it: **Ports** tab → right-click port 443 → **Port Visibility** →
**Public**.

### Reset to a clean site

Inside the codespace:

```bash
bash .devcontainer/install-joomla.sh
```

Drops the database, recreates it, reinstalls from the current working tree.

---

## Path 2 — Local (Docker)

### Requirements

- Docker Desktop **running** (check: `docker info` must succeed)
- `git`, and the `gh` CLI if you want to preview pull requests by number
- ~3 GB free disk for the first build; later previews reuse it

### Deploy

```bash
bin/preview up my-branch      # a branch
bin/preview up 48434          # or any joomla/joomla-cms PR number
bin/preview up a1b2c3d        # or a raw commit
```

The first run for a given ref takes several minutes (image build, `composer
install`, `npm ci`). Later previews are faster — the Composer and npm caches are
shared between them.

It finishes by printing:

```
  Site:     http://localhost:8100
  Admin:    http://localhost:8100/administrator
  Login:    ci-admin / joomla-17082005
  Mailpit:  http://localhost:8101
```

### Manage

```bash
bin/preview list              # what is running, and on which ports
bin/preview up my-branch      # re-run = reset to a clean site
bin/preview down my-branch    # destroy containers, database and worktree
```

Several previews can run at once. Each gets its own containers, its own
database and its own ports (8100, then 8102, then 8104...), so you can compare
two branches side by side.

`down` takes the **slug**, not the ref. For a plain branch name they are the
same; for a branch like `a11y/form-labels` the slug is `a11y-form-labels`.
`bin/preview list` always shows it.

---

## Verify a deployment actually works

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8100/                # expect 200
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8100/administrator/  # expect 200
curl -s http://localhost:8100/ | grep -o '<title>[^<]*</title>'                # expect <title>Home</title>
```

If the front page returns 200 but looks unstyled, the asset build did not
complete — see the first troubleshooting entry.

---

## When it breaks

**Page loads but has no CSS, or Joomla refuses to start**
The repository is not installable as-is: `libraries/vendor`, `node_modules` and
`media/` are not committed and have to be built. Rebuild them:

```bash
bin/preview down my-branch && bin/preview up my-branch
```

**`configuration.php already present! Nothing to install, exiting.`**
The installer refuses to run over an existing config. Delete it and reinstall:

```bash
rm -f configuration.php && bash .devcontainer/install-joomla.sh
```

**`Value for db-prefix is wrong`**
Joomla requires a table prefix that starts with a **letter**, contains only
alphanumerics and underscores, ends with an underscore, and is at most 15
characters. `bin/preview` derives a legal one automatically; you only hit this
if you pass one by hand.

**The `mysql` container restarts in a loop**
Check `docker logs <preview>-mysql-1`. If it says
`unknown variable 'default-authentication-plugin'`, the MySQL image was bumped
to 8.4 or newer, where that option was **removed**. Either pin the image back to
`mysql:8.0` in `docker/compose.yaml` or replace the flag with
`--mysql-native-password=ON`.

**`port is already allocated`**
Something else holds 8100+. Find it with `lsof -iTCP:8100 -sTCP:LISTEN`, or just
destroy the stale preview with `bin/preview down <slug>`.

**Every URL points at `localhost` from inside a codespace**
`$live_site` was not set. Fix it:

```bash
bash .devcontainer/set-live-site.sh
```

**Docker mounts appear empty on macOS**
Docker Desktop only shares configured paths. `/private/tmp` is not shared by
default. Keep previews inside the repository (which is where `bin/preview` puts
them) or add the path in Docker Desktop → Settings → Resources → File Sharing.

**`bin/preview cloud` fails to push**
You need push access to the repository the preview branch goes to. Check with
`gh auth status` that the active account is the right one — `gh auth switch
--user <name>` changes it.

---

## What it is doing under the hood

Five steps, in both paths:

1. Check out the target ref into an isolated worktree (the ref is never modified).
2. Install dependencies: `composer install`, `npm ci` — the latter also builds
   `media/` and `installation/template/css` through its `install` lifecycle script.
3. Recreate an empty database.
4. Install Joomla non-interactively:
   `php installation/joomla.php install --db-type=mysqli ...`
5. Point `$live_site` at the URL the environment is actually reachable on, and
   send mail to Mailpit.

For the cloud path there is one extra step first: a disposable `preview/<branch>`
branch is composed from your commits plus the tooling, because Codespaces can
only use a dev container configuration that exists in the ref it boots from —
and that tooling must never end up in the history of a branch you open an
upstream pull request from.

---

## This is not a production deployment

These are throwaway test environments. They ship things you would never run in
production: `error_reporting=maximum`, debug mode, a known admin password,
phpMyAdmin exposed, mail swallowed by Mailpit, the `installation/` directory
left in place, and a database that is dropped and recreated on demand.

For something persistent — a staging site for a stakeholder to look at over
weeks rather than hours — the shape is different: a small VPS, a real domain
with TLS, a database that is backed up rather than recreated, and
`error_reporting` turned down. Worth doing if someone needs a stable link; it is
not what this tooling is for.

---

## Reference

| Command | Effect |
|---|---|
| `bin/preview-setup` | One-time local setup |
| `bin/preview cloud <branch>` | Push a preview branch, print a Codespaces link |
| `bin/preview up <ref>` | Local preview of a branch, SHA or upstream PR number |
| `bin/preview list` | Running previews and ports |
| `bin/preview down <slug>` | Destroy a preview completely |
| `bin/pr-check <branch>` | Confirm a branch is safe for an upstream pull request |
| `bash .devcontainer/install-joomla.sh` | Reinstall Joomla in the current environment |
| `bash .devcontainer/set-live-site.sh` | Re-point `$live_site` at the current URL |

Deeper detail: `PREVIEW.md` on `tooling/preview`. Guide for Mike:
`PREVIEW-QUICKSTART.md` on `docs/preview-quickstart`.
