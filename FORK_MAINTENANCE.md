# Fork Maintenance Guide

This guide explains how to maintain your fork of the Trino repository with automatic upstream synchronization and private feature branches.

## 🔄 Automated Upstream Sync

A GitHub Actions workflow automatically syncs your fork with the upstream Trino repository daily at 2 AM UTC.

### Workflow Features:
- **Daily sync** via cron schedule
- **Manual trigger** via GitHub UI (workflow_dispatch)
- **Automatic rebase** onto upstream master
- **Conflict detection** with GitHub issue creation
- **Safe push** using `--force-with-lease`

### Workflow File: `.github/workflows/sync-upstream.yml`

## 🚀 Quick Start

### 1. Ensure Your Fork is Set Up

Your repository should already have these remotes configured:

```bash
# Check your remotes
git remote -v

# Expected output:
# origin    https://github.com/deepseek1109/trino.git (fetch)
# origin    https://github.com/deepseek1109/trino.git (push)
# upstream  https://github.com/trinodb/trino.git (fetch)
# upstream  https://github.com/trinodb/trino.git (push)
```

If upstream is missing, add it:

```bash
git remote add upstream https://github.com/trinodb/trino.git
```

### 2. Enable GitHub Actions

1. Go to your fork on GitHub: `https://github.com/deepseek1109/trino`
2. Click **Actions** tab
3. If prompted, click **I understand my workflows, go ahead and enable them**
4. The sync workflow will run automatically

### 3. Run Sync Manually

1. Go to **Actions** tab
2. Click **Sync Fork with Upstream** workflow
3. Click **Run workflow** dropdown
4. (Optional) Enter a specific branch name, or leave as `master`
5. Click **Run workflow**

## 🛠️ Manual Rebase Commands

When automatic sync fails due to conflicts, use these commands:

```bash
# 1. Fetch all remotes
git fetch origin
git fetch upstream

# 2. Checkout your master branch
git checkout master

# 3. Rebase onto upstream
git rebase upstream/master

# 4. Resolve any conflicts (if they occur)
#    - Edit conflicted files
#    - git add <resolved-files>
#    - git rebase --continue

# 5. Push to your fork
git push origin master --force-with-lease
```

## 🌿 Working with Private Feature Branches

### Recommended Workflow:

```bash
# 1. Ensure master is up to date
git checkout master
git pull origin master

# 2. Create your feature branch from master
git checkout -b my-private-feature

# 3. Make your changes and commit
git add .
git commit -m "Add my private feature"

# 4. Push to your fork
git push origin my-private-feature

# 5. When upstream syncs, rebase your feature branch
git checkout master
git pull origin master  # or wait for auto-sync
git checkout my-private-feature
git rebase master

# 6. Resolve conflicts if any, then push
git push origin my-private-feature --force-with-lease
```

## ⚙️ Customization

### Change Sync Schedule

Edit `.github/workflows/sync-upstream.yml`:

```yaml
on:
  schedule:
    # Current: Daily at 2 AM UTC
    - cron: '0 2 * * *'
    
    # Options:
    # Every 6 hours: '0 */6 * * *'
    # Weekly (Sundays at 2 AM): '0 2 * * 0'
    # Every 12 hours: '0 */12 * * *'
```

### Sync Multiple Branches

Add a matrix strategy to sync multiple branches:

```yaml
jobs:
  sync:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        branch: [master, develop, release-480]
    steps:
      # ... steps
      - name: Checkout fork
        uses: actions/checkout@v4
        with:
          ref: ${{ matrix.branch }}
```

## 🐛 Troubleshooting

### Issue: "Permission denied" in GitHub Actions

**Solution:** Ensure workflow permissions:
1. Go to **Settings** → **Actions** → **General**
2. Under "Workflow permissions", select **Read and write permissions**
3. Check **Allow GitHub Actions to create and approve pull requests** (optional)

### Issue: Rebase conflicts

**Solution:** 
1. GitHub Actions will create an issue automatically
2. Follow the manual rebase steps in the issue
3. After resolving, close the issue

### Issue: Force push rejected

**Solution:**
```bash
# Pull latest changes first
git pull origin master --rebase

# Then push
git push origin master
```

## 📋 Best Practices

1. **Never commit directly to master** - Always use feature branches
2. **Regularly sync with upstream** - At least weekly
3. **Rebase feature branches often** - To catch conflicts early
4. **Use `--force-with-lease`** instead of `--force` - Prevents overwriting others' work
5. **Test after rebasing** - Run tests to ensure your changes still work
6. **Keep feature branches focused** - One feature per branch

## 🔗 Useful Links

- [Trino Official Repository](https://github.com/trinodb/trino)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Git Rebase Documentation](https://git-scm.com/docs/git-rebase)
- [Fork Workflow Best Practices](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks)

## 📞 Getting Help

If the automatic sync fails:
1. Check the **Actions** tab for error details
2. Try the manual rebase commands above
3. Check if there are any open issues created by the workflow
4. Review the workflow logs for specific error messages
