#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d "${TMPDIR:-/tmp}/skillset-test.XXXXXX")"
trap 'rm -rf "$workdir"' EXIT

upstream="$workdir/upstream"
consumer="$workdir/consumer"
bin="$workdir/bin"
mkdir -p "$bin"

cat > "$bin/apfel" <<'EOF'
#!/usr/bin/env bash
printf 'dependency\n'
EOF
chmod +x "$bin/apfel"

git init -q -b main "$upstream"
git -C "$upstream" config user.name Test
git -C "$upstream" config user.email test@example.com
mkdir -p "$upstream/skills/example"
cat > "$upstream/skills/example/SKILL.md" <<'EOF'
---
name: example
---

Call the Skill tool with "dependency".
upstream version one
EOF
mkdir -p "$upstream/skills/dependency"
printf '%s\n' '---' 'name: dependency' '---' > "$upstream/skills/dependency/SKILL.md"
git -C "$upstream" add skills
git -C "$upstream" commit -qm 'Add example skill'

git init -q -b main "$consumer"
git -C "$consumer" config user.name Test
git -C "$consumer" config user.email test@example.com
git -C "$consumer" commit --allow-empty -qm 'Initialize skills repository'

(
  cd "$consumer"
  printf 'yes\n' | PATH="$bin:$PATH" "$repo_root/bin/import-skill" --repo "$upstream" --ref main --path skills/example
  test -f skills/dependency/SKILL.md
  mkdir -p skills/local-only
  printf 'local-only skill\n' > skills/local-only/SKILL.md
  git add skills/local-only/SKILL.md
  git commit -qm 'Add local-only skill'
  printf 'unrelated baseline\n' > NOTES.md
  git add NOTES.md
  git commit -qm 'Add unrelated file'
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
  printf 'staged unrelated change\n' >> NOTES.md
  git add NOTES.md
  "$repo_root/bin/rm-skill" example
  "$repo_root/bin/rm-skill" dependency
  test ! -e skills/example
  test ! -e skills/dependency
  test ! -e .skillset/sources.tsv
  git diff --cached -- NOTES.md | grep -F 'staged unrelated change' >/dev/null
  ! git for-each-ref --format='%(refname)' refs/heads/vendor | grep -q .
  ! git remote | grep -q '^skill-source-'
  git commit -qm 'Update unrelated file'
  printf 'yes\n' | PATH="$bin:$PATH" "$repo_root/bin/import-skill" --repo "$upstream" --ref main --path skills/example
  test -f skills/example/SKILL.md
  test -f skills/dependency/SKILL.md
  "$repo_root/bin/rm-skill" local-only
  test ! -e skills/local-only
)

printf 'import-sync-remove: passed\n'
