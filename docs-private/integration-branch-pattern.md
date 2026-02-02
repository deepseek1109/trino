# Integration Branch Pattern: Private Main with Upstream Rebasing

## Overview

This document describes the best practice for maintaining a private main branch (`internal`) that hosts all your internal features while constantly rebasing against upstream changes. This pattern eliminates the pain of conflicting rebases and provides a clean, scalable workflow.

## The Problem

**Anti-pattern:** Putting internal features directly on `main`/`master`

```
master:  A---B---C---D---E (internal features mixed with upstream)
                  ↑
            conflict hell on every rebase
```

**Problems:**
- Every upstream update causes conflicts
- Tedious manual conflict resolution
- Risk of losing internal features
- Hard to track what came from where
- Blocking other team members during rebases

## The Solution: Integration Branch Pattern

### Branch Architecture

```
upstream/master ────────► origin/master (clean mirror, NEVER commit here)
        │                          │
        │                          │ (fast-forward only)
        │                          ▼
        │                   origin/internal (your private main)
        │                          │
        │                          │ (merge with --no-ff)
        │                          ▼
        ├──────────────► feature/internal-{auth,metrics,cache} (individual features)
```

**Key insight:** Your `master` stays 100% identical to upstream. All your work happens on `internal`, which is periodically rebased onto the updated `master`.

## Setup Instructions

### Step 1: Enable Rerere (Critical!)

Rerere = "Reuse Recorded Resolution" - Git remembers how you resolved conflicts.

```bash
# Enable globally (do this once on your machine)
git config --global rerere.enabled true

# Verify it's enabled
git config rerere.enabled  # Should output: true
```

**Why this matters:** After resolving a conflict once, rerere automatically reapplies that resolution on future rebases. After 3-4 cycles, rebases become automatic.

### Step 2: Configure Remotes

```bash
# Check current remotes
git remote -v

# Should show:
# origin  https://github.com/YOUR_USERNAME/trino.git (fetch)
# origin  https://github.com/YOUR_USERNAME/trino.git (push)
# upstream  https://github.com/trinodb/trino.git (fetch)
# upstream  https://github.com/trinodb/trino.git (push)

# Add upstream if missing
git remote add upstream https://github.com/trinodb/trino.git
```

### Step 3: Create Clean Master

```bash
# Ensure you're on master and it's clean
git checkout master
git fetch upstream
git reset --hard upstream/master  # MAKE SURE master is IDENTICAL to upstream!
git push origin master --force-with-lease  # Update your fork's master
```

**⚠️ Warning:** Only do this if master has no unique commits you need to keep!

### Step 4: Create Internal Branch

```bash
# Create internal from the clean master
git checkout -b internal

# Add your first internal feature
# (see "Adding Features" section below)

# Push and set as default
git push -u origin internal
```

Then on GitHub: **Settings → Branches → Default branch → Switch to `internal`**

## Daily Workflow

### Scenario 1: Upstream Has Updates (Automated or Manual)

```bash
# Step 1: Update master from upstream
git checkout master
git fetch upstream
git merge upstream/master --ff-only  # Fast-forward only - no merge commits
git push origin master

# Step 2: Rebase internal onto updated master
git checkout internal
git rebase master

# If conflicts occur:
# 1. Resolve them (rerere may auto-resolve)
# 2. git add <resolved-files>
# 3. git rebase --continue

# Step 3: Push internal
git push origin internal --force-with-lease

# Step 4: Verify tests pass, then notify team
```

### Scenario 2: Adding a New Internal Feature

```bash
# Create feature branch from internal
git checkout internal
git checkout -b feature/internal-ldap-integration

# Do your work
# ... make commits ...

# When ready to integrate:
git checkout internal
git merge feature/internal-ldap-integration --no-ff
git push origin internal

# Optional: Delete feature branch
git branch -d feature/internal-ldap-integration
git push origin --delete feature/internal-ldap-integration
```

### Scenario 3: Updating a Feature Branch

```bash
# If internal has moved forward and you need to update your feature:
git checkout feature/internal-ldap-integration
git rebase internal

# Resolve any conflicts, then:
git push origin feature/internal-ldap-integration --force-with-lease
```

## GitHub Actions Automation

### Workflow 1: Sync Master (Safe, Automated)

`.github/workflows/sync-master.yml`:

```yaml
name: Sync Master with Upstream

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM UTC
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
      
      - name: Sync with upstream
        run: |
          git remote add upstream https://github.com/trinodb/trino.git
          git fetch upstream
          
          # Fast-forward only - fails if diverged
          git merge upstream/master --ff-only
          
          git push origin master
```

### Workflow 2: Rebase Internal (Manual Trigger)

`.github/workflows/rebase-internal.yml`:

```yaml
name: Rebase Internal onto Master

on:
  workflow_dispatch:
    inputs:
      test_first:
        description: 'Run tests before pushing?'
        required: false
        default: true
        type: boolean

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
      
      - name: Configure git
        run: |
          git config user.name 'github-actions[bot]'
          git config user.email 'github-actions[bot]@users.noreply.github.com'
      
      - name: Fetch master
        run: |
          git fetch origin master
      
      - name: Rebase internal onto master
        id: rebase
        run: |
          git rebase origin/master
          echo "rebased=true" >> $GITHUB_OUTPUT
      
      - name: Run tests (optional)
        if: inputs.test_first
        run: |
          ./mvnw clean test -DskipTests=false -pl '!docs'
      
      - name: Push rebased internal
        if: success()
        run: |
          git push origin internal --force-with-lease
      
      - name: Create issue on failure
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: '⚠️ Internal branch rebase failed',
              body: `Manual rebase required.\n\nSteps:\n1. git fetch origin\n2. git checkout internal\n3. git rebase origin/master\n4. Resolve conflicts\n5. git push origin internal --force-with-lease`,
              labels: ['rebase-failed']
            });
```

## Conflict Resolution Strategy

### When Conflicts Happen

```bash
git checkout internal
git rebase master

# CONFLICT (content): Merge conflict in core/trino-main/pom.xml
# error: could not apply <commit-hash>... Your internal feature
```

### Resolution Steps

1. **See what conflicts:**
   ```bash
   git status
   ```

2. **View conflict markers:**
   ```bash
   grep -n "<<<<<<<" core/trino-main/pom.xml
   ```

3. **Edit and resolve** (choose upstream or yours)

4. **Stage resolved files:**
   ```bash
   git add core/trino-main/pom.xml
   ```

5. **Continue rebase:**
   ```bash
   git rebase --continue
   ```

6. **If stuck, abort and retry:**
   ```bash
   git rebase --abort
   # Try merge strategy instead:
   git merge master
   ```

### Using Rerere Effectively

```bash
# See recorded resolutions
git rerere status

# See what rerere remembers
git rerere diff

# Forget a resolution (if it was wrong)
git rerere forget <file>
```

## Alternative: Merge Instead of Rebase

If rebasing causes too much pain, use merge:

```bash
git checkout internal
git merge master --no-ff  # Creates a merge commit
git push origin internal
```

**Pros:**
- No conflict resolution during sync
- Preserves all history exactly as it happened
- Safer for teams
- Easier to understand

**Cons:**
- "Messier" history with merge commits
- Harder to read linear log
- Can't easily squash later

**Recommendation:** Start with rebase (cleaner history), switch to merge if it becomes painful.

## Team Coordination

### Branch Protection Rules

On GitHub, protect these branches:

1. **master:**
   - Require pull request reviews before merging
   - Restrict pushes to GitHub Actions only
   - Require status checks to pass

2. **internal:**
   - Require pull request reviews
   - Allow force pushes (needed for rebase)
   - Require tests to pass

### Communication Protocol

```bash
# Before rebasing internal, notify team:
# 1. Check if anyone has unmerged feature branches
git branch -a --merged internal | grep feature/

# 2. Post in Slack/Teams:
# "Rebasing internal in 30 minutes. Please merge or push any pending feature branches."

# 3. After rebase, notify:
# "Internal rebased onto upstream/master. Update your feature branches:
#  git fetch origin && git rebase origin/internal"
```

### Feature Branch Management

**Naming Convention:**
```
feature/internal-<feature-name>
feature/internal-ldap-auth
feature/internal-metrics-dashboard
feature/internal-query-caching
```

**Lifecycle:**
1. Create from `internal`
2. Develop with regular commits
3. Rebase onto `internal` when `internal` moves
4. Merge to `internal` with `--no-ff` when complete
5. Delete feature branch

## Advanced Patterns

### Pattern 1: Release Branches

If you need stable releases:

```bash
# Create release branch from internal
git checkout internal
git checkout -b release/v480-internal
git push origin release/v480-internal

# Release branches never rebase - only merge
# This gives you stable history for debugging
```

### Pattern 2: Staging Internal

For large teams or risky changes:

```bash
internal-stable      # Always works, only fast-forward updates
      │
      ▼ (rebase)
internal-staging     # Test changes here first
      │
      ▼ (merge when stable)
feature/internal-xyz # Individual features
```

### Pattern 3: Partial Rebasing

If internal has both "safe" and "risky" features:

```bash
# Create layers:
internal-safe        # Stable, well-tested internal features
      │
      ▼ (rebase)
internal-beta        # Experimental features
      │
      ▼ (rebase)
master               # Pure upstream
```

## Troubleshooting

### Problem: Rebase has too many conflicts

**Solution:** Use merge instead for this cycle:
```bash
git rebase --abort
git merge master --no-ff
```

Then switch to merge workflow going forward.

### Problem: Team member pushed to internal during rebase

**Solution:** Coordinate better! But if it happens:
```bash
# Save your work
git checkout -b internal-backup

# Reset and retry
git checkout internal
git fetch origin
git reset --hard origin/internal  # Get their changes
git rebase master

# If conflicts with their changes, resolve together
```

### Problem: Internal diverged too far from master

**Solution:** Gradual catch-up:
```bash
# Instead of one big rebase, do incremental:
git checkout internal
git rebase master~50  # Rebase onto 50 commits ago
git push --force-with-lease
git rebase master~25  # Rebase onto 25 commits ago
git push --force-with-lease
git rebase master     # Finally rebase onto current master
git push --force-with-lease
```

### Problem: Want to contribute internal feature upstream

**Solution:** Cherry-pick to clean branch:
```bash
# Find the feature commits on internal
git log master..internal --oneline

# Create clean branch from upstream master
git fetch upstream
git checkout -b feature/upstream-ldap upstream/master

# Cherry-pick your commits (clean them up first if needed)
git cherry-pick <commit-hash>

# Push and create PR to upstream
git push origin feature/upstream-ldap
```

## Summary: Key Principles

| Principle | Why It Matters |
|-----------|---------------|
| **Master stays clean** | Never commit to master directly |
| **Internal is your main** | All work happens on internal |
| **Enable rerere** | Automates conflict resolution |
| **Use --force-with-lease** | Safer than --force |
| **Fast-forward master** | Keeps history linear and clean |
| **Feature branches** | Isolate work, enable parallel development |
| **Automate sync** | GitHub Actions reduces manual work |
| **Communicate** | Notify team before major rebases |

## Quick Reference

```bash
# Daily sync (automated or manual)
git checkout master && git fetch upstream && git merge upstream/master --ff-only && git push origin master
git checkout internal && git rebase master && git push origin internal --force-with-lease

# New feature
git checkout internal && git checkout -b feature/internal-XYZ
# ... work ...
git checkout internal && git merge feature/internal-XYZ --no-ff && git push origin internal

# Update feature branch
git checkout feature/internal-XYZ && git rebase internal && git push --force-with-lease
```

## Further Reading

- [Git Rerere Documentation](https://git-scm.com/docs/git-rerere)
- [Git Rebasing](https://git-scm.com/book/en/v2/Git-Branching-Rebasing)
- [Git Branching Strategies](https://www.atlassian.com/git/tutorials/comparing-workflows)
- [Trino Development Process](https://trino.io/development/process.html)
