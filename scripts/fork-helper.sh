#!/bin/bash
# Quick reference script for manual fork maintenance
# Source this script: source ./scripts/fork-helper.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Trino Fork Helper Functions Loaded${NC}"
echo "Available commands:"
echo "  sync_upstream    - Sync master with upstream"
echo "  rebase_feature   - Rebase current branch onto master"
echo "  create_feature   - Create new feature branch from updated master"
echo ""

# Function to sync master with upstream
sync_upstream() {
    echo -e "${YELLOW}Syncing master with upstream...${NC}"
    
    # Fetch all remotes
    git fetch origin
    git fetch upstream
    
    # Checkout master
    git checkout master
    
    # Rebase onto upstream
    git rebase upstream/master
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Rebase successful${NC}"
        echo -e "${YELLOW}Pushing to origin...${NC}"
        git push origin master --force-with-lease
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Master synced successfully!${NC}"
        else
            echo -e "${RED}✗ Push failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Rebase failed. Resolve conflicts manually:${NC}"
        echo "  1. Fix conflicts in files"
        echo "  2. git add <resolved-files>"
        echo "  3. git rebase --continue"
        echo "  4. git push origin master --force-with-lease"
        return 1
    fi
}

# Function to rebase current feature branch onto master
rebase_feature() {
    local current_branch=$(git branch --show-current)
    
    if [ "$current_branch" = "master" ]; then
        echo -e "${RED}✗ Cannot rebase master onto itself${NC}"
        echo "Switch to a feature branch first"
        return 1
    fi
    
    echo -e "${YELLOW}Rebasing feature branch '${current_branch}' onto master...${NC}"
    
    # Fetch latest
    git fetch origin
    
    # Rebase
    git rebase origin/master
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Feature branch rebased successfully${NC}"
        echo -e "${YELLOW}Pushing to origin...${NC}"
        git push origin "$current_branch" --force-with-lease
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Feature branch updated!${NC}"
        else
            echo -e "${RED}✗ Push failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Rebase failed. Resolve conflicts manually${NC}"
        return 1
    fi
}

# Function to create new feature branch
create_feature() {
    local branch_name=$1
    
    if [ -z "$branch_name" ]; then
        echo -e "${RED}✗ Please provide a branch name${NC}"
        echo "Usage: create_feature <branch-name>"
        return 1
    fi
    
    echo -e "${YELLOW}Creating feature branch '${branch_name}'...${NC}"
    
    # Ensure master is up to date
    git checkout master
    git pull origin master
    
    # Create and checkout new branch
    git checkout -b "$branch_name"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Feature branch '${branch_name}' created!${NC}"
        echo "Make your changes, then:"
        echo "  git add ."
        echo "  git commit -m 'Your commit message'"
        echo "  git push origin ${branch_name}"
    else
        echo -e "${RED}✗ Failed to create branch${NC}"
        return 1
    fi
}

# Show current status
fork_status() {
    echo -e "${YELLOW}=== Fork Status ===${NC}"
    
    echo -e "\n${GREEN}Remotes:${NC}"
    git remote -v
    
    echo -e "\n${GREEN}Current branch:${NC}"
    git branch --show-current
    
    echo -e "\n${GREEN}Branch list:${NC}"
    git branch -v
    
    echo -e "\n${GREEN}Upstream sync status:${NC}"
    git fetch upstream --dry-run 2>&1 | head -5
    
    echo ""
}

# Export functions
export -f sync_upstream
export -f rebase_feature
export -f create_feature
export -f fork_status
