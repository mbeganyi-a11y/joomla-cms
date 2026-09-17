# Access and permissions — what is blocked, and how to unblock it

The preview environments are built, pushed and working. Two small pieces of the
setup cannot be finished from a collaborator account, and this document explains
exactly why and what the options are.

Nothing is broken and nothing is waiting on this. The command-line path
(`bin/preview cloud`) already does everything. What is blocked is only the
GitHub-UI conveniences.

---

## TL;DR

`mbeganyi-a11y/joomla-cms` is owned by a **user account**, not an organization.
GitHub only offers granular repository roles — Triage, Write, Maintain, Admin —
on **organization-owned** repositories. A repository owned by a personal account
has exactly two levels: the **owner**, and **collaborators with write access**.

So an account that is not `mbeganyi-a11y` can never hold admin rights on this
repository. That is not a setting anyone forgot to flip; the role does not exist
for personal repositories.

Common misreading worth correcting: this has nothing to do with the repository
being a *fork*. A fork owned by an organization would allow Admin to be granted
normally. It is the *user-owned* part that does it.

---

## What works, and what does not

Current access for `mcandio`: **write**.

| Action | Needs | Status |
|---|---|---|
| Push branches, force-push, delete branches | write | ✅ works |
| Add workflow files | write | ✅ works |
| Open and comment on pull requests | write | ✅ works |
| Compose and push `preview/*` branches (`bin/preview cloud`) | write | ✅ works |
| Change the default branch | **admin** | ❌ blocked |
| Enable Issues / Discussions | **admin** | ❌ blocked |
| Configure Codespaces prebuilds | **admin** | ❌ blocked |
| Add repository secrets or variables | **admin** | ❌ blocked |
| Branch protection rules / rulesets | **admin** | ❌ blocked |
| Manage collaborators | **admin** | ❌ blocked |

One note on diagnosing this: for repository settings the GitHub API answers
**`HTTP 404 Not Found`**, not `403 Forbidden`, when the token lacks admin. It is
deliberate — GitHub does not confirm the existence of resources you cannot
administer. So a 404 on `PATCH /repos/{owner}/{repo}` means "not allowed", not
"wrong URL".

```
$ gh repo edit mbeganyi-a11y/joomla-cms --default-branch tooling/preview
HTTP 404: Not Found (https://api.github.com/repos/mbeganyi-a11y/joomla-cms)

$ gh repo edit mbeganyi-a11y/joomla-cms --enable-issues
HTTP 404: Not Found (https://api.github.com/repos/mbeganyi-a11y/joomla-cms)
```

Separately: **forks have Issues disabled by default**, which is why this
repository has no issue tracker. That one is just a checkbox — but it is an
admin checkbox.

---

## What is actually blocked, in practice

Small, and both have working substitutes:

1. **The `/preview` comment trigger and the Actions "Run workflow" button.**
   GitHub reads `workflow_dispatch`, `issue_comment` and `schedule` workflows
   from the **default branch only**, and the default branch is `5.4-dev`, which
   must stay a pristine mirror of upstream so the tooling cannot live there.
   → Substitute: `bin/preview cloud <branch>` performs the identical overlay
   from the command line and needs only push access.

2. **Codespaces prebuilds**, which would cut first-boot time from several
   minutes to about one.
   → Substitute: none, it is just slower. Purely a comfort issue.

3. **An issue tracker on this fork**, for coordinating the work.
   → Substitute: pull requests, which is what PR #1 is doing.

---

## Options

### Option A — host the preview infrastructure in a separate fork (recommended)

`mcandio` creates a fork of `joomla/joomla-cms` and the preview tooling lives
there. As the owner of that repository, everything above becomes available
immediately: default branch, prebuilds, Issues, secrets.

Mike's fork then holds only his working branches and stays completely clean,
which is the outcome we wanted anyway. Previews of his branches are composed in
the other fork by fetching his refs — `bin/preview cloud` already builds the
preview branch from an arbitrary ref, so it only needs to push to a different
remote.

- No action required from Mike beyond his repository being readable.
- No waiting on anyone; can be done today.
- Codespaces still bill to whoever opens them, so Mike's previews use Mike's
  own free monthly allowance, as they do now.
- A GitHub account can hold only one fork per upstream repository, and `mcandio`
  currently has none — so this is available.

### Option B — move the fork into a GitHub organization

Create a free organization, transfer the fork into it, and repository roles
become available: `mcandio` can be granted **Admin** or **Maintain** properly.

- Best long-term answer if more people will touch this, or if the work needs to
  be visible to the company rather than sitting in a personal account.
- Free for public repositories.
- Requires Mike to create the organization and transfer the repository. A
  transfer keeps stars, watchers, branches and pull requests, and sets up
  redirects from the old URL, so nothing breaks.
- Note that transferring changes the repository URL, so existing clones need
  `git remote set-url` (the redirect covers it in the meantime).

### Option C — Mike runs the admin actions himself

Two commands, once:

```bash
gh repo edit mbeganyi-a11y/joomla-cms --default-branch tooling/preview
gh repo edit mbeganyi-a11y/joomla-cms --enable-issues
```

Plus configuring the prebuild in Settings → Codespaces → Prebuild
configuration, on the `tooling/preview` branch.

- Cheapest, changes nothing structurally.
- Downside: Mike is the bottleneck for every future settings change, and there
  will be a few over six weeks.

Safe to do? Yes. Changing the default branch is harmless for a fork: pull
requests to `joomla/joomla-cms` choose their base branch upstream, not here. It
only affects what this fork shows by default and where the workflow triggers are
read from.

---

## Recommendation

**Option A now, Option B if this outgrows two people.**

Option A removes every blocker today without needing anything from Mike, and it
reinforces the separation we already want: infrastructure in one place, the
accessibility branches that become upstream pull requests in another, with no
chance of the two mixing.

Option C is fine too if Mike would rather keep everything in one repository —
it is two commands. The only real cost is that he becomes the bottleneck for
settings.

---

## For reference — what is already done

| Branch | Contents |
|---|---|
| `tooling/preview` | The preview tooling and `PREVIEW.md` |
| `docs/preview-quickstart` | `PREVIEW-QUICKSTART.md`, the guide for Mike |
| `docs/access-and-permissions` | This document |
| `preview/5.4-dev` | A disposable example preview branch, safe to delete |
| `5.4-dev` | Untouched, still a mirror of upstream (currently behind it) |
