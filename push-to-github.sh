#!/bin/bash

###############################################################################
# Push Hackathon Infrastructure to GitHub
#
# Prerequisites:
# 1. Create a Personal Access Token on GitHub:
#    https://github.com/settings/tokens
# 2. Select 'repo' scope
# 3. Copy the token (ghp_xxxxxxxxxxxx)
###############################################################################

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  GitHub Push Setup for pl-hackathon2025${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check if in correct directory
if [ ! -d ".git" ]; then
    echo -e "${RED}Error: Not in a git repository!${NC}"
    echo "Please run this script from /home/user/pl-hackathon2025"
    exit 1
fi

echo -e "${GREEN}Step 1: Create Personal Access Token${NC}"
echo "--------------------------------------"
echo "1. Go to: https://github.com/settings/tokens"
echo "2. Click: 'Generate new token' → 'Tokens (classic)'"
echo "3. Note: 'pl-hackathon2025-deployment'"
echo "4. Expiration: 90 days"
echo "5. Check the 'repo' scope ✅"
echo "6. Click 'Generate token'"
echo "7. Copy the token (starts with ghp_)"
echo ""

# Prompt for token
echo -e "${YELLOW}Enter your GitHub Personal Access Token:${NC}"
read -s GITHUB_TOKEN
echo ""

if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}Error: Token cannot be empty!${NC}"
    exit 1
fi

echo -e "${GREEN}Step 2: Verifying repository setup...${NC}"
echo "--------------------------------------"

# Show current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# Show commit
LAST_COMMIT=$(git log --oneline -1)
echo "Last commit: $LAST_COMMIT"

# Count files
FILE_COUNT=$(git ls-files | wc -l)
echo "Files to push: $FILE_COUNT"
echo ""

echo -e "${GREEN}Step 3: Configuring remote with token...${NC}"
echo "--------------------------------------"

# Update remote URL with token
git remote set-url origin https://${GITHUB_TOKEN}@github.com/champand/pl-hackathon2025.git

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Remote configured successfully${NC}"
else
    echo -e "${RED}✗ Failed to configure remote${NC}"
    exit 1
fi
echo ""

echo -e "${GREEN}Step 4: Pushing to GitHub...${NC}"
echo "--------------------------------------"

# Push to GitHub
git push -u origin ${CURRENT_BRANCH}

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}  ✓ Successfully pushed to GitHub!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo "View your code at:"
    echo -e "${BLUE}https://github.com/champand/pl-hackathon2025/tree/${CURRENT_BRANCH}${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Go to GitHub repository"
    echo "2. Create a Pull Request (if needed)"
    echo "3. Review and merge changes"
else
    echo ""
    echo -e "${RED}=========================================${NC}"
    echo -e "${RED}  ✗ Push failed!${NC}"
    echo -e "${RED}=========================================${NC}"
    echo ""
    echo "Common issues:"
    echo "1. Token might be invalid or expired"
    echo "2. Token might not have 'repo' permission"
    echo "3. Network connectivity issues"
    echo ""
    echo "Try:"
    echo "- Verify token is correct"
    echo "- Regenerate token with 'repo' scope"
    echo "- Check network connection"
    exit 1
fi

# Security: Remove token from remote URL for safety
echo ""
echo -e "${YELLOW}Removing token from git config for security...${NC}"
git remote set-url origin https://github.com/champand/pl-hackathon2025.git
echo -e "${GREEN}✓ Token removed from local config${NC}"
echo ""

echo -e "${GREEN}All done! 🎉${NC}"
