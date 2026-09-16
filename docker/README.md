# Local preview stack

Driven by `bin/preview` — see [`../PREVIEW.md`](../PREVIEW.md).

```bash
bin/preview up <pr-number|branch|sha>
bin/preview list
bin/preview down <slug>
```

Do not run `docker compose` in here directly: `compose.yaml` expects
`PREVIEW_SLUG`, `PREVIEW_WORKTREE`, `PREVIEW_TOOLING`, `PREVIEW_PORT` and
`PREVIEW_MAIL_PORT`, which `bin/preview` sets per preview.

The compose project is named `joomla-preview-${PREVIEW_SLUG}`, so containers,
networks and the database volume are isolated per preview.

`compose.yaml` lives here rather than at the repository root because the
upstream `.gitignore` ignores `/docker-compose.yml`.
