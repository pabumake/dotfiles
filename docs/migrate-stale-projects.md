---
layout: default
title: Code archive offload
---

# Code archive offload

`migrate-stale-projects.sh` moves inactive code projects through a verified,
two-step archive process. The Mac copy stays under `~/src/archive` until a
separate purge command verifies the finalized NAS copy again.

The canonical script and configuration live in the dotfiles repository:

```text
~/src/dotfiles/scripts/migrate-stale-projects.sh
~/src/dotfiles/scripts/migrate-stale-projects.conf
```

The dotfiles bootstrap creates this convenience link:

```text
~/src/archive/migrate-stale-projects.sh
```

## Safety model

The utility processes one explicitly named project at a time. It has no
scheduler, bulk mode, age-based selection, automatic overwrite, or automatic
source deletion.

Before transfer it requires:

- Homebrew `rsync` 3.x at the configured path.
- Absolute, non-overlapping source and target paths, with the target inside the configured NAS mount.
- The configured NAS volume and target directory.
- A real project directory directly below `SOURCE_ROOT`.
- A clean working tree for every Git repository in the project.
- Every local branch and tag to exist at an approved Forgejo or GitHub remote.
- No finalized NAS directory or unfinished incoming transfer with the same name.

`migrate` copies into a run-specific `.incoming` directory. It rejects source
changes, verifies the copy with checksum-based rsync, runs Git connectivity
checks, restores and compares a test file, then renames the verified directory
to its final NAS name. The local source remains untouched.

`purge` repeats verification and requires the complete project name on standard
input before it removes the exact direct child under `SOURCE_ROOT`.

## Configuration

The default configuration is
`~/src/dotfiles/scripts/migrate-stale-projects.conf`. Set
`ARCHIVE_MIGRATION_CONFIG` to test another configuration.

The file uses allowlisted `KEY=VALUE` entries. Do not use shell expressions,
quotes, spaces around `=`, or commands. Unknown keys stop the utility.

| Key | Purpose |
| --- | --- |
| `SOURCE_ROOT` | Local staging directory for inactive code projects |
| `TARGET_ROOT` | Canonical NAS project archive |
| `TARGET_MOUNT_ROOT` | Mount whose presence must be verified |
| `RSYNC_BIN` | Required rsync 3.x executable |
| `ALLOWED_REMOTE_MARKERS` | Comma-separated strings accepted in Git remote URLs |
| `MIN_FREE_BYTES` | Minimum free bytes required on the target |
| `REQUIRE_MOUNT` | `1` for production; `0` only for controlled local tests |

## Usage

List staged projects:

```bash
~/src/archive/migrate-stale-projects.sh list
```

Inspect one transfer without writing to the NAS:

```bash
~/src/archive/migrate-stale-projects.sh plan 2026-03-project-name
```

Copy, verify, and finalize the NAS archive while keeping the Mac source:

```bash
~/src/archive/migrate-stale-projects.sh migrate 2026-03-project-name
```

Repeat verification before removal:

```bash
~/src/archive/migrate-stale-projects.sh verify 2026-03-project-name
```

Permanently remove the verified Mac staging copy:

```bash
~/src/archive/migrate-stale-projects.sh purge 2026-03-project-name
```

Type the complete project name when prompted. A wrong or missing confirmation
leaves the source untouched.

## Failure recovery

If transfer or verification fails, the source remains unchanged. Inspect the
run-specific directory below `/Volumes/datastore0/project-archive/.incoming`.
Do not rename or merge it manually. Remove it only after deciding that the
failed transfer is no longer needed, then run `plan` again.

If a finalized destination already exists, the utility stops. Compare the two
copies manually and choose a new approved plan. The utility never guesses that
two project directories are equivalent.

## Tests

The tests use temporary local directories and local bare Git remotes. They do
not access the NAS or contact Forgejo or GitHub.

```bash
cd ~/src/dotfiles
/bin/bash scripts/tests/migrate-stale-projects.test.sh
```
