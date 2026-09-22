#!/usr/bin/env bats

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  workdir="$(mktemp -d "${TMPDIR:-/tmp}/skillset-test.XXXXXX")"
  upstream="$workdir/upstream"
  consumer="$workdir/consumer"
  bin="$workdir/bin"
  mkdir -p "$bin"

  # Keep dependency detection deterministic, regardless of developer tooling.
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$bin/fm"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$bin/apfel"
  chmod +x "$bin/fm" "$bin/apfel"

  git init -q -b main "$upstream"
  git -C "$upstream" config user.name Test
  git -C "$upstream" config user.email test@example.com
  write_upstream_skill 'upstream version one'
  git -C "$upstream" add skills
  git -C "$upstream" commit -qm 'Add example skill'

  git init -q -b main "$consumer"
  git -C "$consumer" config user.name Test
  git -C "$consumer" config user.email test@example.com
  git -C "$consumer" commit --allow-empty -qm 'Initialize skills repository'
}

teardown() {
  rm -rf "$workdir"
}

write_upstream_skill() {
  mkdir -p "$upstream/skills/example"
  printf '%s\n' '---' 'name: example' '---' '' "$1" > "$upstream/skills/example/SKILL.md"
}

commit_upstream_change() {
  git -C "$upstream" add skills/example/SKILL.md
  git -C "$upstream" commit -qm "$1"
}

import_example() {
  (
    cd "$consumer"
    printf 'no\n' | PATH="$bin:$PATH" "$repo_root/bin/import-skill" --repo "$upstream" --ref main --path skills/example
  )
}

import_skill() {
  (
    cd "$consumer"
    printf 'no\n' | PATH="$bin:$PATH" "$repo_root/bin/import-skill" --repo "$upstream" --ref main --path "skills/$1"
  )
}

remove_example() {
  (
    cd "$consumer"
    "$repo_root/bin/rm-skill" example
  )
}

sync_example() {
  (
    cd "$consumer"
    "$repo_root/bin/sync-skill" example
  )
}

assert_success() {
  [[ "$status" -eq 0 ]] || {
    printf 'Expected success, got status %s:\n%s\n' "$status" "$output" >&2
    return 1
  }
}

assert_failure() {
  [[ "$status" -ne 0 ]] || {
    printf 'Expected failure, got success:\n%s\n' "$output" >&2
    return 1
  }
}

assert_signed_commit() {
  git -C "$1" cat-file -p "$2" | grep -q '^gpgsig '
}

@test "adds an imported skill and records its provenance" {
  run import_example

  assert_success
  [ -f "$consumer/skills/example/SKILL.md" ]
  run git -C "$consumer" log --format=%s -2
  assert_success
  [[ "$output" == *'Track example upstream source'* ]]
  [[ "$output" == *'Import example from'* ]]
  assert_signed_commit "$consumer" 'HEAD^^'
  assert_signed_commit "$consumer" 'HEAD^^2'
  run grep -F "skills/example	$upstream	main	skills/example" "$consumer/.skillset/sources.tsv"
  assert_success
}

@test "rejects adding a skill that already exists" {
  import_example

  run import_example

  assert_failure
  [[ "$output" == *'destination already exists: skills/example'* ]]
  run git -C "$consumer" log --format=%s -1
  assert_success
  [ "$output" = 'Track example upstream source' ]
}

@test "does not sign subtree commits when commit signing is disabled" {
  git -C "$consumer" config commit.gpgSign false

  run import_example

  assert_success
  ! git -C "$consumer" cat-file -p 'HEAD^^' | grep -q '^gpgsig '
  ! git -C "$consumer" cat-file -p 'HEAD^^2' | grep -q '^gpgsig '
}

@test "lists and adds direct referenced skills when requested" {
  rm "$bin/fm"
  cat > "$bin/apfel" <<'EOF'
#!/usr/bin/env bash
source_file=''
while [[ $# -gt 0 ]]; do
  if [[ "$1" == -f ]]; then
    [[ -n "$source_file" ]] || source_file="$2"
    shift 2
  else
    shift
  fi
done
if grep -Fqx 'name: example' "$source_file"; then
  printf '%s\n' dependency shared unrelated
fi
EOF
  chmod +x "$bin/apfel"
  printf '%s\n' '---' 'name: example' '---' '' 'Call the Skill tool with "dependency" and "shared".' > "$upstream/skills/example/SKILL.md"
  mkdir -p "$upstream/skills/dependency" "$upstream/skills/shared" "$upstream/skills/unrelated"
  printf '%s\n' '---' 'name: dependency' '---' > "$upstream/skills/dependency/SKILL.md"
  printf '%s\n' '---' 'name: shared' '---' > "$upstream/skills/shared/SKILL.md"
  printf '%s\n' '---' 'name: unrelated' '---' > "$upstream/skills/unrelated/SKILL.md"
  git -C "$upstream" add skills
  git -C "$upstream" commit -qm 'Add skill dependencies'

  run bash -c "cd \"$consumer\" && printf 'yes\\n' | PATH=\"$bin:\$PATH\" \"$repo_root/bin/import-skill\" --repo \"$upstream\" --ref main --path skills/example"

  assert_success
  [[ "$output" == *'The upstream skill example explicitly references:'* ]]
  [[ "$output" == *'  - dependency'* ]]
  [[ "$output" == *'  - shared'* ]]
  [[ "$output" != *'  - unrelated'* ]]
  [ -f "$consumer/skills/example/SKILL.md" ]
  [ -f "$consumer/skills/dependency/SKILL.md" ]
  [ -f "$consumer/skills/shared/SKILL.md" ]
  [ ! -e "$consumer/skills/unrelated" ]
  [ "$(git -C "$consumer" log --format=%s | grep -Fc 'Import shared from')" -eq 1 ]
}

@test "removes an imported skill and cleans up its provenance" {
  import_example

  run remove_example

  assert_success
  [ ! -e "$consumer/skills/example" ]
  [ ! -e "$consumer/.skillset/sources.tsv" ]
  [ -z "$(git -C "$consumer" for-each-ref '--format=%(refname)' refs/heads/vendor)" ]
  [ -z "$(git -C "$consumer" remote)" ]
}

@test "rejects removing a skill that does not exist" {
  run remove_example

  assert_failure
  [[ "$output" == *'skill directory does not exist: skills/example'* ]]
}

@test "adds a skill and then removes it" {
  import_example
  remove_example

  run git -C "$consumer" status --short

  assert_success
  [ -z "$output" ]
  [ ! -e "$consumer/skills/example" ]
}

@test "adds, removes, and re-adds a skill" {
  import_example
  remove_example

  run import_example

  assert_success
  [ -f "$consumer/skills/example/SKILL.md" ]
  [ -f "$consumer/.skillset/sources.tsv" ]
}

@test "removes a local-only skill without creating source metadata" {
  mkdir -p "$consumer/skills/local-only"
  printf 'local-only skill\n' > "$consumer/skills/local-only/SKILL.md"
  git -C "$consumer" add skills/local-only/SKILL.md
  git -C "$consumer" commit -qm 'Add local-only skill'

  run bash -c "cd \"$consumer\" && \"$repo_root/bin/rm-skill\" local-only"

  assert_success
  [ ! -e "$consumer/skills/local-only" ]
  [ ! -e "$consumer/.skillset/sources.tsv" ]
  [ "$(git -C "$consumer" log --format=%s -1)" = 'Remove local-only skill' ]
}

@test "syncs an unmodified skill with upstream changes" {
  import_example
  printf 'upstream version two\n' >> "$upstream/skills/example/SKILL.md"
  commit_upstream_change 'Update example skill'

  run sync_example

  assert_success
  run grep -Fx 'upstream version two' "$consumer/skills/example/SKILL.md"
  assert_success
  run git -C "$consumer" log --format=%s -2
  assert_success
  [[ "$output" == *'Sync example from'* ]]
  [[ "$output" == *'Track example upstream revision'* ]]
  assert_signed_commit "$consumer" 'HEAD^^'
  assert_signed_commit "$consumer" 'HEAD^^2'
}

@test "does not sign subtree sync commits when commit signing is disabled" {
  import_example
  git -C "$consumer" config commit.gpgSign false
  printf 'upstream version two\n' >> "$upstream/skills/example/SKILL.md"
  commit_upstream_change 'Update example skill'

  run sync_example

  assert_success
  ! git -C "$consumer" cat-file -p 'HEAD^^' | grep -q '^gpgsig '
  ! git -C "$consumer" cat-file -p 'HEAD^^2' | grep -q '^gpgsig '
}

@test "syncs a locally modified skill when the changes do not conflict" {
  import_example
  printf 'local customization\n' > "$consumer/skills/example/LOCAL.md"
  git -C "$consumer" add skills/example/LOCAL.md
  git -C "$consumer" commit -qm 'Customize example skill'
  printf 'upstream version two\n' >> "$upstream/skills/example/SKILL.md"
  commit_upstream_change 'Update example skill'

  run sync_example

  assert_success
  run grep -Fx 'local customization' "$consumer/skills/example/LOCAL.md"
  assert_success
  run grep -Fx 'upstream version two' "$consumer/skills/example/SKILL.md"
  assert_success
}

@test "leaves a conflict for deliberate resolution when local and upstream edits overlap" {
  import_example
  write_upstream_skill 'upstream conflicting change'
  commit_upstream_change 'Change example upstream'
  printf '%s\n' '---' 'name: example' '---' '' 'local conflicting change' > "$consumer/skills/example/SKILL.md"
  git -C "$consumer" add skills/example/SKILL.md
  git -C "$consumer" commit -qm 'Change example locally'

  run sync_example

  assert_failure
  run git -C "$consumer" status --short
  assert_success
  [[ "$output" == *'UU skills/example/SKILL.md'* ]]
  run grep -F '<<<<<<<' "$consumer/skills/example/SKILL.md"
  assert_success
}

@test "reports an already-current skill without creating a commit" {
  import_example
  before="$(git -C "$consumer" rev-parse HEAD)"

  run sync_example

  assert_success
  [[ "$output" == *'example is already up to date.'* ]]
  [ "$(git -C "$consumer" rev-parse HEAD)" = "$before" ]
}

@test "rejects import and sync with a dirty worktree" {
  printf 'uncommitted change\n' > "$consumer/NOTES.md"
  git -C "$consumer" add NOTES.md

  run import_example

  assert_failure
  [[ "$output" == *'commit or stash changes before importing a skill'* ]]
  git -C "$consumer" commit -qm 'Add notes'
  import_example
  printf 'uncommitted change\n' >> "$consumer/NOTES.md"
  git -C "$consumer" add NOTES.md

  run sync_example

  assert_failure
  [[ "$output" == *'commit or stash changes before syncing skills'* ]]
}

@test "removes a skill without staging unrelated changes" {
  import_example
  printf 'staged unrelated change\n' > "$consumer/NOTES.md"
  git -C "$consumer" add NOTES.md

  run remove_example

  assert_success
  run git -C "$consumer" diff --cached -- NOTES.md
  assert_success
  [[ "$output" == *'staged unrelated change'* ]]
}

@test "retains a shared source remote until its last imported skill is removed" {
  mkdir -p "$upstream/skills/other"
  printf '%s\n' '---' 'name: other' '---' > "$upstream/skills/other/SKILL.md"
  git -C "$upstream" add skills/other/SKILL.md
  git -C "$upstream" commit -qm 'Add other skill'
  import_example
  import_skill other
  remote="$(git -C "$consumer" remote | grep '^skill-source-')"

  remove_example

  assert_success
  [ -d "$consumer/skills/other" ]
  [ "$(git -C "$consumer" remote)" = "$remote" ]
  run bash -c "cd \"$consumer\" && \"$repo_root/bin/rm-skill\" other"
  assert_success
  [ -z "$(git -C "$consumer" remote)" ]
}
