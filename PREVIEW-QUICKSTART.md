# Preview environments — quickstart

A throwaway Joomla site for any branch, commit or pull request. Two ways to get
one: in the cloud (one click, gives you a shareable URL) or locally with Docker
(offline, full fidelity).

Everything lives on the **`tooling/preview`** branch of this fork. This document
is the only file on its own branch so it is easy to read; the tooling itself is
not here.

---

## TL;DR

```bash
git clone git@github.com:mbeganyi-a11y/joomla-cms.git
cd joomla-cms
git checkout tooling/preview
bin/preview-setup                    # once

bin/preview cloud my-branch          # cloud preview -> prints a Codespaces link
bin/preview up my-branch             # local preview -> http://localhost:8100
```

Admin login for every preview: **`ci-admin` / `joomla-17082005`**

---

## Screen readers work against a cloud preview

You mentioned you were not sure you could get reliable screen reader output in a
cloud environment. You can — with one caveat worth being precise about.

NVDA, JAWS and VoiceOver read the accessibility tree of **the browser running on
your own machine**. It makes no difference that the PHP server is in a codespace
in a datacenter. Open the forwarded URL in your normal Chrome or Firefox and
drive it exactly as you would against localhost.

What genuinely does not work is running a screen reader *inside* a CI container
and capturing its output programmatically. That is not attempted anywhere in
this setup, and it is the only thing the cloud takes away from you.

So the preview is always a plain HTTPS URL you open yourself — never a
browser-in-the-cloud / VNC session.

If you still prefer local for any reason, `bin/preview up` gives you the same
site on `localhost` running the same PHP and Apache build.

---

## The one rule that matters

**Always branch off a pristine `upstream/5.4-dev`.** Never off
`tooling/preview`, never off a `preview/*` branch.

A GitHub pull request diffs `merge-base(base, head)...head`, so anything in your
branch's history that upstream does not have shows up in the diff. The preview
tooling must never reach `joomla/joomla-cms`, so:

```bash
git fetch upstream 5.4-dev
git checkout -b my-a11y-fix upstream/5.4-dev
# ... your 1-2 commits ...
bin/pr-check my-a11y-fix
```

`bin/pr-check` prints exactly what a pull request from that branch would
contain, warns if it is more than 2 commits, and fails loudly if any fork-only
tooling leaked in — with the commands to rebuild the branch cleanly.

You never have to add the tooling to your branch to get a preview. The cloud
path composes a separate disposable `preview/<branch>` branch (your commits +
the tooling) and boots the codespace from that. Your branch is not touched.

> **Heads up:** this fork's `5.4-dev` is currently behind
> `joomla/joomla-cms`. Sync it before you start, or your pull requests will sit
> on a stale base:
>
> ```bash
> git fetch upstream 5.4-dev
> git push origin upstream/5.4-dev:5.4-dev
> ```

---

## Cloud preview (Codespaces)

```bash
git push origin my-a11y-fix
bin/preview cloud my-a11y-fix
```

It prints a link like
`https://codespaces.new/mbeganyi-a11y/joomla-cms/tree/preview/my-a11y-fix`.
Open it, wait for the boot, and the terminal prints the site URL, the admin URL
and the credentials. They are also saved to `codespace-details.txt`.

Ports inside the codespace: **443** the site, **8081** phpMyAdmin, **8025**
Mailpit (every mail Joomla sends lands there instead of being delivered).

### Sharing the URL

The forwarded port is private by default, which is fine for you — you are
authenticated. To let someone without access to the codespace open it: **Ports**
tab → right-click port 443 → **Port Visibility** → **Public**.

### Making boots fast

Out of the box a codespace pays for `composer install`, `npm ci` and the asset
build on first boot, which is several minutes. A **prebuild** on
`tooling/preview` (Settings → Codespaces → Prebuild configuration) bakes that
into the image. Worth doing if you are going to create a lot of these.

### Optional: trigger previews from the GitHub UI

There is also a workflow (`.github/workflows/preview.yml`) that does the same
thing from **Actions → Preview environment → Run workflow**, or from a
`/preview` comment on a pull request opened in this fork.

It needs one repository setting first, and **only you can do it** — it requires
admin rights on the fork:

```bash
gh repo edit mbeganyi-a11y/joomla-cms --default-branch tooling/preview
```

The reason is that GitHub reads `workflow_dispatch`, `issue_comment` and
`schedule` workflows from the **default branch only**, and `5.4-dev` has to stay
a pristine mirror of upstream so the tooling cannot live there. It is safe for a
fork — pull requests to `joomla/joomla-cms` pick their base branch upstream, not
here.

This is purely a convenience. `bin/preview cloud` already does the same job with
no special permissions, so nothing is blocked on it.

---

## Local preview (Docker)

Needs Docker Desktop, `git` and the `gh` CLI.

```bash
bin/preview-setup              # once: local ignores + the 'upstream' remote
bin/preview up my-a11y-fix     # a branch...
bin/preview up 48434           # ...or any joomla/joomla-cms PR number
bin/preview list
bin/preview down my-a11y-fix
```

The site comes up on `http://localhost:8100` (next preview gets 8102, and so
on), with Mailpit on the port above it.

Each preview gets its own git worktree under `.previews/`, its own containers,
its own database and its own ports, so you can run several side by side and
compare. The previewed commit is checked out detached and is never modified.

First run for a given ref installs dependencies and takes a few minutes.
Composer and npm caches are shared between previews, so later ones are quicker.

Useful extras:

- **Reset a preview to a clean site:** `bin/preview up <same-ref>` — it drops
  and recreates the database and reinstalls from scratch.
- **Inside a codespace, same thing:** `bash .devcontainer/install-joomla.sh`

---

## What is not included

**Accessibility baseline metrics.** This is deploy tooling only — it gets you a
site to look at, it does not count issues for you.

For the record, so nobody goes looking: the repository has no scanning tooling
at all today. No axe-core, pa11y, Lighthouse or cypress-axe anywhere. The only
accessibility code in the codebase is runtime — `plugins/system/jooa11y`, which
is an in-browser visual checker with no machine-readable output, and
`plugins/system/accessibility`, the toolbar widget.

If you want the numbers automated for the baseline re-runs, it is a short job
and the hook points already exist: add `cypress-axe` + `axe-core` as dev
dependencies, a command in `tests/System/support/commands.mjs`, an aggregating
task in `tests/System/plugins/index.mjs` writing to `tests/System/output/`
(which CI already uploads as an artifact with `if: always()`), and a new spec
tree `tests/System/integration/a11y/` added to `specPattern` **after**
`install/` — that ordering matters, the `install/` specs are what install the
CMS. One gotcha: the `afterEach` in `tests/System/support/index.js` runs
`checkForPhpNoticesOrWarnings`, `checkForLogs` and `cleanupDB` on every test, so
a11y specs would inherit those assertions.

Say the word and it can be added.

---

## Reference

| Command | What it does |
|---|---|
| `bin/preview-setup` | One-time local setup: `.git/info/exclude` entries and the `upstream` remote |
| `bin/preview cloud <branch>` | Pushes a disposable `preview/*` branch, prints a Codespaces link |
| `bin/preview up <ref>` | Local preview of a branch, SHA or upstream PR number |
| `bin/preview list` | Running local previews and their ports |
| `bin/preview down <slug>` | Destroys containers, database and worktree |
| `bin/pr-check <branch>` | Verifies a branch is safe to open an upstream pull request from |

Full detail, including how the isolation works and why the devcontainer scripts
are split the way they are: **`PREVIEW.md` on the `tooling/preview` branch**.

Two things to be aware of, flagged rather than assumed:

- Whether codespaces created from `preview/*` branches pick up a prebuild
  configured on `tooling/preview` has not been confirmed. If they do not,
  everything still works, it is just slower on first boot.
- Making port 443 public from inside the codespace via
  `gh codespace ports visibility` may need a personal access token, because the
  in-codespace token does not carry the `codespace` scope. The two-click route
  in the Ports tab always works.
