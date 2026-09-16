# Preview environments for accessibility work

Spin up a throwaway Joomla site for any branch, commit or pull request — in the
cloud (one click, shareable URL) or locally (offline, full fidelity).

Everything here lives on the **`tooling/preview` branch of this fork only**. It is
built so that it can never reach `joomla/joomla-cms`.

---

## The isolation rule (read this first)

A GitHub pull request shows `merge-base(base, head)...head`. Anything in your
branch's history that upstream does not have appears in the diff. So:

> **Always branch off a pristine `upstream/5.4-dev`. Never off `tooling/preview`,
> never off a `preview/*` branch.**

```bash
git fetch upstream 5.4-dev
git checkout -b my-a11y-fix upstream/5.4-dev
# ... do the work, 1-2 commits ...
bin/pr-check my-a11y-fix     # verifies the PR would contain only your changes
```

`bin/pr-check` lists exactly what a pull request from that branch would contain,
warns if it exceeds the agreed 1–2 commit scope, and fails loudly if any
fork-only tooling leaked in (with the recipe to recreate the branch cleanly).

Two further safeguards, both deliberate:

- **`.gitignore` is never modified.** It is tracked upstream, so even a one-line
  addition would show up in a pull request. Local ignores go in
  `.git/info/exclude` via `bin/preview-setup`.
- **The cloud preview never runs on your branch.** Codespaces can only use a dev
  container configuration present in the ref it boots from, so instead of adding
  one to your branch, `.github/workflows/preview.yml` composes a disposable
  `preview/<branch>` branch = your commits + the tooling, and boots from that.
  Your branch is never touched.

---

## Repository setup (once)

### 1. Make `tooling/preview` the fork's default branch

Not optional, and the reason is not cosmetic: GitHub reads workflows for the
`workflow_dispatch`, `issue_comment` and `schedule` events from the **default
branch only**. While `5.4-dev` is the default branch, `preview.yml` can never be
triggered. And `5.4-dev` has to stay a pristine mirror of upstream, so the
tooling cannot live there.

```bash
gh repo edit mbeganyi-a11y/joomla-cms --default-branch tooling/preview
```

This is safe for a fork: pull requests to `joomla/joomla-cms` are unaffected,
because their base branch is chosen upstream, not here.

### 2. Keep `5.4-dev` a pristine mirror

Never commit to it. Refresh it with:

```bash
git fetch upstream 5.4-dev
git push origin upstream/5.4-dev:5.4-dev
```

### 3. Configure a Codespaces prebuild

Settings → Codespaces → Prebuild configuration, on the `tooling/preview` branch,
triggered on push and on configuration change. See "Making it fast" below.

> Prebuilds are configured per branch, so verify that codespaces created from
> `preview/*` branches actually pick up the prebuild — if they do not, the
> tooling still works, it is just slower on first boot.

---

## Cloud preview (Codespaces)

Best for: a URL you can share, and for screen reader testing.

1. Push your branch to this fork.
2. Trigger the preview:
   - **Actions → Preview environment → Run workflow**, enter your branch; or
   - comment `/preview` on a pull request opened in this fork.
3. The run summary gives you a **one-click Codespace link**. Open it.

When it boots, the terminal (and `codespace-details.txt`) prints the site URL,
the admin URL and the credentials — `ci-admin` / `joomla-17082005`.

### Screen readers work fine against a cloud preview

NVDA, JAWS and VoiceOver read the accessibility tree of **the browser on your own
machine**. It makes no difference that the PHP server is in a codespace. Open the
forwarded URL in your normal Chrome or Firefox and drive it as usual.

What does *not* work is running a screen reader inside a CI container and
capturing its output — that is not attempted anywhere here.

To let someone without access to your codespace open the URL: **Ports** tab →
right-click port 443 → **Port Visibility** → **Public**.

### Making it fast

Without a prebuild, a codespace pays for `composer install`, `npm ci` and the
asset build on first boot (~10 min). Configure a **prebuild** on the
`tooling/preview` branch (Settings → Codespaces → Prebuild configuration) and
that work is baked into the image.

The scripts are split accordingly:

| Script | Runs | Contains |
|---|---|---|
| `.devcontainer/post-create.sh` | create time, **baked into the prebuild** | `composer install`, `npm ci`, Cypress binary, Apache config |
| `.devcontainer/post-start.sh` | **every** start | start Apache, install Joomla if the database is empty, set `$live_site` |
| `.devcontainer/install-joomla.sh` | on demand | full reinstall — also your "reset to a clean site" button |
| `.devcontainer/set-live-site.sh` | every start | point `$live_site` at this codespace's hostname |

The split is not cosmetic. A prebuild bakes the *workspace*, but every new
codespace gets an **empty database volume**, so installing Joomla at create time
would leave a `configuration.php` pointing at a database with no tables.
`$live_site` likewise depends on `$CODESPACE_NAME`, which differs per codespace.

> Note: prebuilds bill storage even when the compute is inside the free monthly
> allowance. At this scale it is cents, not zero.

---

## Local preview (Docker)

Best for: offline work, and maximum fidelity for screen reader testing.

```bash
bin/preview-setup            # once: local excludes + upstream remote
bin/preview up 48434         # an upstream PR number...
bin/preview up my-a11y-fix   # ...or a branch, or a SHA
bin/preview list
bin/preview down my-a11y-fix
```

Each preview gets its own git worktree under `.previews/`, its own containers,
its own database volume and its own ports, so several can run at once. The
previewed ref is checked out **detached and never modified** — tooling is
bind-mounted into the container from the tooling branch at `/tooling`.

The stack reuses `.devcontainer/Dockerfile`, so a local preview runs the same
PHP and Apache build as a cloud one. First run for a ref builds dependencies
(a few minutes); Composer and npm caches are shared volumes, so later previews
are fast.

---

## What this does not do

Accessibility **baseline metrics** are not implemented. The repository currently
has no scanning tooling at all — no axe-core, pa11y, Lighthouse or cypress-axe
anywhere. The only accessibility code is runtime: `plugins/system/jooa11y`
(an in-browser visual checker, no machine-readable output) and
`plugins/system/accessibility`.

When you want it, the hook point is short: add `cypress-axe` + `axe-core` as dev
dependencies, a command in `tests/System/support/commands.mjs`, an aggregating
task in `tests/System/plugins/index.mjs` writing to `tests/System/output/`
(already archived by `ci.yml` with `if: always()`), and a spec tree
`tests/System/integration/a11y/` added to `specPattern` **after** `install/` —
that ordering matters, `install/` is what installs the CMS. Be aware that the
`afterEach` in `tests/System/support/index.js` runs `checkForPhpNoticesOrWarnings`,
`checkForLogs` and `cleanupDB` on every test, so a11y specs inherit those
assertions.
