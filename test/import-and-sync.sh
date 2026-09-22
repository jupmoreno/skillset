#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/skillset-test.XXXXXX")"
trap 'rm -rf "$workdir"' EXIT

upstream="$workdir/upstream"
consumer="$workdir/consumer"

git init -q -b main "$upstream"
git -C "$upstream" config user.name Test
git -C "$upstream" config user.email test@example.com
mkdir -p "$upstream/skills/example"
printf 'upstream version one\n' > "$upstream/skills/example/SKILL.md"
git -C "$upstream" add skills
git -C "$upstream" commit -qm 'Add example skill'

git init -q -b main "$consumer"
git -C "$consumer" config user.name Test
git -C "$consumer" config user.email test@example.com
git -C "$consumer" commit --allow-empty -qm 'Initialize skills repository'

(
  cd "$consumer"
  "$repo_root/bin/import-skill" --repo "$upstream" --ref main --path skills/example
  mkdir -p skills/local-only
  printf 'local-only skill\n' > skills/local-only/SKILL.md
  git add skills/local-only/SKILL.md
  git commit -qm 'Add local-only skill'
  printf 'local customization\n' > skills/example/LOCAL.md
  git add skills/example/LOCAL.md
  git commit -qm 'Customize example skill'
)

printf 'upstream version two\n' >> "$upstream/skills/example/SKILL.md"
git -C "$upstream" add skills/example/SKILL.md
git -C "$upstream" commit -qm 'Update example skill'

(
  cd "$consumer"
  "$repo_root/bin/sync-skill" example
  grep -Fx 'upstream version one' skills/example/SKILL.md >/dev/null
  grep -Fx 'local customization' skills/example/LOCAL.md >/dev/null
  grep -Fx 'upstream version two' skills/example/SKILL.md >/dev/null
  "$repo_root/bin/rm-skill" example
  git add -u .skillset skills/example
  git commit -qm 'Remove imported example skill'
  test ! -e skills/example
  test ! -e .skillset/sources.tsv
  ! git for-each-ref --format='%(refname)' refs/heads/vendor | grep -q .
  ! git remote | grep -q '^skill-source-'
  "$repo_root/bin/rm-skill" local-only
  git add -u skills/local-only
  git commit -qm 'Remove local-only skill'
  test ! -e skills/local-only
)

printf 'import-sync-remove: passed\n'
