# Skillset

## Usage

### Import

Import one skill from a GitHub directory URL:

```bash
bin/import-skill https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs
```

The skill is added as `skills/grill-with-docs/`. Pass a second argument to use a
different local name:

```bash
bin/import-skill https://github.com/mattpocock/skills/tree/main/skills/engineering/grill-with-docs docs-grill
```

Importing a skill creates the subtree and source-metadata commits.

If `fm` or `apfel` is installed, the importer uses it to identify explicit
references to other upstream skills. It prints the full dependency tree and
asks whether to import all missing referenced skills before importing the
requested skill.

For another Git host or source reference, provide the repository, branch, and
directory explicitly:

```bash
bin/import-skill --repo https://github.com/acme/skills.git --ref main \
  --path skills/review --name acme-review
```

### Sync

Merge upstream changes for one imported skill:

```bash
bin/sync-skill grill-with-docs
```

Merge updates for every imported skill:

```bash
bin/sync-skill
```

If both copies changed the same lines, resolve the Git merge conflict, then stage
and commit the resolution yourself. Syncing a skill creates subtree and
source-metadata commits when updates are available.

### Remove

Remove an imported or local-only skill:

```bash
bin/rm-skill grill-with-docs
```

Remove several skills in one commit:

```bash
bin/rm-skill grill-with-docs domain-modeling
```

`rm-skill` commits the selected removal and source-registry update while
leaving unrelated staged and unstaged work unchanged. Commit or stash changes
to the selected skill or `.skillset/sources.tsv` before removing it.

## Building

### Test

The import, sync, and removal workflows are covered by Bats integration tests
that use temporary local Git repositories:

```bash
bats test/import-sync.bats
```
