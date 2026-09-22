# Skillset

This repository is the canonical source for personal AI skills. Imported skills
are ordinary files under `skills/`, so local customizations are committed and
pushed with this repository. Their upstream source is retained in
`.skillset/sources.tsv` for later merges.

## Add a Skill

Initialize and make the first commit before importing skills:

```bash
git add .
git commit -m "Initialize skillset"
```

Use a GitHub directory URL to import exactly one upstream skill:

```bash
bin/add-skill https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs
```

The command imports it into `skills/grill-with-docs/`, records its source, and
creates the Git commits needed for future synchronization. To use a different
local name, pass it as the second argument:

```bash
bin/add-skill https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs docs-grill
```

For Git hosts or source references that are not GitHub tree URLs, use explicit
arguments:

```bash
bin/add-skill --repo https://github.com/acme/skills.git --ref main \
  --path skills/review --name acme-review
```

## Customize and Sync

Edit any imported files and commit normally:

```bash
git add skills/grill-with-docs
git commit -m "Customize grill-with-docs"
git push
```

To merge new changes from the source skill's recorded branch and path:

```bash
bin/sync-skill grill-with-docs
```

To update every imported skill:

```bash
bin/sync-skill
```

If both copies changed the same lines, `git subtree` stops with a normal merge
conflict. Resolve it, `git add` the resolution, and commit it before continuing.
The importer preserves the upstream directory's history rather than squashing it,
so non-overlapping upstream and local edits merge normally.

## Install

The `skills/` directories are regular repository content, with no submodules or
symlinks. After pushing this repository, install it with the Vercel Skills CLI:

```bash
npx skills add <your-github-user>/skillset
```

Consult `npx skills --help` for its current options to install a selected skill
or target a particular AI coding tool.

## Verify

The integration test creates temporary repositories, imports one directory,
adds a local customization, and verifies that a later upstream update merges:

```bash
test/import-and-sync.sh
```
