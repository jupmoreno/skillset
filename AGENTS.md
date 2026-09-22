# Skillset Agent Guide

## Purpose

Skillset is a Git-backed collection of agent skills. It must support all of the
following without sacrificing any of them:

- Import skills from external Git repositories.
- Modify an imported skill locally when needed.
- Merge future changes from that skill's original source.
- Create and maintain skills that exist only in this repository.
- Install the collection with Vercel's Skills CLI.

Treat source provenance and updateability as core product behavior, not optional
metadata. Do not replace an import/sync workflow with a one-time file copy.

## Repository Layout

- `skills/<name>/`: a skill directory. A valid skill normally has `SKILL.md`.
- `bin/import-skill`: imports one upstream skill as a Git subtree and records
  its source.
- `bin/sync-skill`: fetches and merges new revisions for imported skills.
- `bin/rm-skill`: removes imported or local-only skills without committing.
- `.skillset/sources.tsv`: authoritative mapping for imported skills only.
- `test/import-and-sync.sh`: end-to-end coverage for importing, local changes,
  syncing, and removal.

## Skill Types

### Imported Skills

Imported skills are tracked in `.skillset/sources.tsv`. Each record contains the
local path, repository, ref, upstream path, remote, vendor branch, and last
merged upstream commit. `bin/import-skill` creates the subtree and source
metadata commits; `bin/sync-skill` uses that record to merge upstream changes.

Local edits to an imported skill are allowed. Preserve the subtree history and
source record so Git can merge those edits with future upstream revisions. If a
sync conflicts, resolve the conflict deliberately and commit the resolution;
never delete the source mapping to avoid resolving a conflict.

### Local-Only Skills

Create first-party skills directly under `skills/<name>/`. Do not add them to
`.skillset/sources.tsv` unless they were imported from an upstream Git source.
They are owned and updated entirely by this repository.

## Required Workflow

1. Import an upstream skill with `bin/import-skill`, not by copying files into
   `skills/`.
2. Commit or stash worktree changes before running `import-skill`, `sync-skill`,
   or `rm-skill`; these commands require a clean worktree.
3. Update imported skills with `bin/sync-skill <name>` or `bin/sync-skill`.
4. Use `bin/rm-skill <name>` to remove either type of skill. Review, stage, and
   commit its changes yourself.
5. When changing the import, sync, or removal behavior, update
   `test/import-and-sync.sh` and run it.

Do not manually edit, discard, or fabricate `.skillset/sources.tsv` rows. Do
not use destructive Git commands to make a subtree update appear clean. Do not
turn a sourced skill into a local-only skill without an explicit migration
decision and preserved provenance.

## Installation

Keep this repository compatible with Vercel's Skills CLI. The consumer-facing
installation command is:

```bash
npx skills add <owner>/<repository>
```

Skills must remain discoverable beneath `skills/` and retain their `SKILL.md`
manifests. Do not reorganize the collection or add tool-specific generated
artifacts in a way that prevents `npx skills add` from installing it.

## Validation

After changing the management scripts or skill-source behavior, run:

```bash
test/import-and-sync.sh
```

Before completing any change, inspect `git diff` and confirm imported-skill
provenance remains accurate and local-only skills remain unregistered.
