# Skillset

## Import

Create an initial commit before importing the first skill:

```bash
git add .
git commit -m "Initialize skillset"
```

Import one skill from a GitHub directory URL:

```bash
bin/import-skill https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs
```

The skill is added as `skills/grill-with-docs/`. Pass a second argument to use a
different local name:

```bash
bin/import-skill https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs docs-grill
```

For another Git host or source reference, provide the repository, branch, and
directory explicitly:

```bash
bin/import-skill --repo https://github.com/acme/skills.git --ref main \
  --path skills/review --name acme-review
```

## Sync

Merge upstream changes for one imported skill:

```bash
bin/sync-skill grill-with-docs
```

Merge updates for every imported skill:

```bash
bin/sync-skill
```

If both copies changed the same lines, resolve the Git merge conflict, stage the
resolution, and commit it.

## Remove

Remove an imported or local-only skill:

```bash
bin/rm-skill grill-with-docs
```

Remove several skills in one commit:

```bash
bin/rm-skill grill-with-docs domain-modeling
```
