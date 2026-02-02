# Fork Maintenance with Integration Branch Pattern

A consolidated guide for maintaining a Trino fork with a private main branch (`internal`) that hosts internal features while constantly rebasing against upstream.

## Branch Architecture

```
upstream/master ────► origin/master (clean mirror, NEVER commit)
        │                      │
        │                      │ (fast-forward only)
        │                      ▼
        │               origin/internal (your private main)
        │                      │
        │                      │ (merge --no-ff)
        │                      ▼
        ├──────────────► feature/internal-{auth,metrics,cache}
```

**Key Principle:** `master` stays 100% identical to upstream. All work happens on `internal`, which is periodically rebased onto updated `master`.

## Quick Setup

### 1. Enable Rerere (Critical!)
```bash
git config --global rerere.enabled true  # Auto-remembers conflict resolutions
git config rerere.enabled  # Verify: should output "true"
```

### 2. Configure Remotes
```bash
git remote add upstream https://github.com/trinodb/trino.git
git remote -v  # Should show origin (your fork) and upstream
```

### 3. Setup Branches
```bash
# Clean master (⚠️ destructive if master has unique commits)
git checkout master
git fetch upstream
git reset --hard upstream/master
git push origin master --force-with-lease

# Create internal from clean master
git checkout -b internal
git push -u origin internal
```

### 4. Set Default Branch
On GitHub: **Settings → Branches → Default branch → `internal`**

## Daily Workflows

### Sync with Upstream
```bash
# Update master (automated via GitHub Actions or manual)
git checkout master
git fetch upstream
git merge upstream/master --ff-only
git push origin master

# Rebase internal
git checkout internal
git rebase master
# Resolve conflicts if needed, then:
git push origin internal --force-with-lease
```

### Add Internal Feature
```bash
git checkout internal
git checkout -b feature/internal-<feature-name>
# ... work ...
git checkout internal
git merge feature/internal-<feature-name> --no-ff
git push origin internal
git branch -d feature/internal-<feature-name>
```

### Update Feature Branch
```bash
git checkout feature/internal-<feature-name>
git rebase internal
git push --force-with-lease
```

## GitHub Actions Automation

### Workflow 1: Sync Master (`.github/workflows/sync-master.yml`)
```yaml
name: Sync Master with Upstream
on:
  schedule:
    - cron: '0 2 * * *'  # Daily 2 AM UTC
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          ref: master
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}
      - run: |
          git remote add upstream https://github.com/trinodb/trino.git
          git fetch upstream
          git merge upstream/master --ff-only
          git push origin master
```

### Workflow 2: Rebase Internal (`.github/workflows/rebase-internal.yml`)
```yaml
name: Rebase Internal onto Master
on:
  workflow_dispatch:  # Manual trigger only

jobs:
  rebase:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          ref: internal
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}
      - run: |
          git config user.name 'github-actions[bot]'
          git config user.email 'github-actions[bot]@users.noreply.github.com'
          git fetch origin master
          git rebase origin/master
          git push origin internal --force-with-lease
      - uses: actions/github-script@v7
        if: failure()
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: '⚠️ Internal branch rebase failed',
              body: 'Manual rebase required.\n\n1. git fetch origin\n2. git checkout internal\n3. git rebase origin/master\n4. Resolve conflicts\n5. git push origin internal --force-with-lease',
              labels: ['rebase-failed']
            });
```

## Conflict Resolution

```bash
# When conflicts occur during rebase:
git status                    # See conflicted files
git add <resolved-files>      # Stage resolved files
git rebase --continue         # Continue rebase

# If stuck:
git rebase --abort            # Abort and retry
git merge master --no-ff      # Alternative: use merge instead
```

### Using Rerere
```bash
git rerere status       # See recorded resolutions
git rerere diff         # See remembered resolutions
git rerere forget <file> # Forget a wrong resolution
```

## Alternative: Merge vs Rebase

**Rebase (default):**
- Cleaner linear history
- Requires conflict resolution
- Use with `rerere` for automation

**Merge (if rebasing is painful):**
```bash
git checkout internal
git merge master --no-ff
git push origin internal
```
- No conflict resolution during sync
- "Messier" history with merge commits
- Safer for teams

## Team Coordination

### Before Rebasing Internal
```bash
# Check for unmerged feature branches
git branch -a --merged internal | grep feature/

# Notify team:
# "Rebasing internal in 30min. Please merge pending feature branches."
```

### Branch Protection Rules

**master:**
- Restrict pushes (GitHub Actions only)
- Require status checks

**internal:**
- Require PR reviews
- Allow force pushes (needed for rebase)
- Require tests

## Quick Reference

| Task | Command |
|------|---------|
| **Daily sync** | `git checkout master && git fetch upstream && git merge upstream/master --ff-only && git push origin master && git checkout internal && git rebase master && git push origin internal --force-with-lease` |
| **New feature** | `git checkout internal && git checkout -b feature/internal-XYZ && git checkout internal && git merge feature/internal-XYZ --no-ff && git push origin internal` |
| **Update feature** | `git checkout feature/internal-XYZ && git rebase internal && git push --force-with-lease` |

## Key Principles

1. **Master stays clean** — Never commit to master directly
2. **Internal is your main** — All work happens on internal
3. **Enable rerere** — Automates conflict resolution (critical!)
4. **Use `--force-with-lease`** — Safer than `--force`
5. **Feature branches** — `feature/internal-<name>` pattern
6. **Communicate** — Notify team before rebasing internal
7. **Automate** — Let GitHub Actions handle master sync

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Too many conflicts | Use `git merge` instead of `git rebase` |
| Team pushed during rebase | `git checkout -b internal-backup`, reset to origin/internal, retry |
| Diverged too far | Gradual rebase: `git rebase master~50`, then `~25`, then `master` |
| Permission denied (Actions) | Settings → Actions → General → Read and write permissions |
| Contribute feature upstream | `git log master..internal`, cherry-pick to clean branch from upstream/master |

## Further Reading

- [Git Rerere](https://git-scm.com/docs/git-rerere)
- [Git Rebasing](https://git-scm.com/book/en/v2/Git-Branching-Rebasing)
- [Trino Development](https://trino.io/development/process.html)
