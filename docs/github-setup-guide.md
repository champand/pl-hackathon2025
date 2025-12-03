# GitHub Personal Access Token Setup Guide

## Overview

This guide will help you create a Personal Access Token (PAT) to authenticate with GitHub and push your code to the repository.

## Step 1: Create Personal Access Token

### Navigate to GitHub Token Settings

1. **Log in to GitHub**: Go to https://github.com and sign in
2. **Access Settings**:
   - Click your profile picture (top right corner)
   - Click **Settings**
3. **Navigate to Developer Settings**:
   - Scroll down in the left sidebar
   - Click **Developer settings** (at the bottom)
4. **Access Personal Access Tokens**:
   - Click **Personal access tokens**
   - Click **Tokens (classic)** or **Fine-grained tokens** (recommended)

### Option A: Fine-Grained Token (Recommended - More Secure)

**Best for**: Repository-specific access with minimal permissions

1. Click **Generate new token** → **Generate new token (fine-grained)**

2. **Configure Token**:
   - **Token name**: `pl-hackathon2025-deployment`
   - **Expiration**: 90 days (or custom)
   - **Description**: `Token for deploying hackathon infrastructure`
   - **Repository access**: Select **Only select repositories**
   - Choose: `champand/pl-hackathon2025`

3. **Repository Permissions** (Select these):
   - **Contents**: Read and write ✅
   - **Metadata**: Read-only (automatically selected) ✅
   - **Pull requests**: Read and write ✅ (if you want to create PRs)

4. Click **Generate token**

5. **IMPORTANT**: Copy the token immediately!
   ```
   github_pat_11AXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
   ```
   ⚠️ You won't be able to see it again!

### Option B: Classic Token (Easier, Broader Access)

**Best for**: Quick setup, multiple repositories

1. Click **Generate new token** → **Generate new token (classic)**

2. **Configure Token**:
   - **Note**: `pl-hackathon2025-deployment`
   - **Expiration**: 90 days (recommended)
   - **Select scopes**:
     - ✅ `repo` (Full control of private repositories)
       - This includes: `repo:status`, `repo_deployment`, `public_repo`, `repo:invite`, `security_events`

3. Scroll down and click **Generate token**

4. **IMPORTANT**: Copy the token immediately!
   ```
   ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
   ⚠️ Save it securely - you won't see it again!

## Step 2: Store Token Securely

### On Linux/Mac

```bash
# Save token to a file (temporary)
echo "YOUR_TOKEN_HERE" > ~/.github-token
chmod 600 ~/.github-token

# Or set as environment variable
export GITHUB_TOKEN="YOUR_TOKEN_HERE"
```

### On Windows

```powershell
# Save as environment variable
$env:GITHUB_TOKEN="YOUR_TOKEN_HERE"

# Or using Command Prompt
set GITHUB_TOKEN=YOUR_TOKEN_HERE
```

## Step 3: Configure Git to Use Token

### Method 1: Use Git Credential Manager (Recommended)

```bash
# Configure git to use credential manager
git config --global credential.helper store

# When you push, enter:
# Username: your-github-username
# Password: YOUR_TOKEN (paste your PAT here, not your GitHub password)
```

### Method 2: Embed Token in Remote URL (Quick, Less Secure)

```bash
cd /home/user/pl-hackathon2025

# Update remote URL with token
git remote set-url origin https://YOUR_TOKEN@github.com/champand/pl-hackathon2025.git

# Now you can push without being prompted
git push -u origin claude/aws-multi-account-design-01D8vATHhW3mNaQw5ZtdKD15
```

⚠️ **Security Warning**: This stores the token in plain text in `.git/config`

### Method 3: Use SSH Keys (Most Secure, One-Time Setup)

**Setup SSH Key** (if you don't have one):

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your-email@example.com"
# Press Enter to accept default location
# Enter passphrase (optional but recommended)

# Start SSH agent
eval "$(ssh-agent -s)"

# Add SSH key
ssh-add ~/.ssh/id_ed25519

# Copy public key
cat ~/.ssh/id_ed25519.pub
# Copy the output
```

**Add SSH Key to GitHub**:

1. Go to GitHub → Settings → SSH and GPG keys
2. Click **New SSH key**
3. Title: `Hackathon Deployment Server`
4. Paste your public key
5. Click **Add SSH key**

**Update Git Remote to Use SSH**:

```bash
cd /home/user/pl-hackathon2025

# Change remote URL to SSH
git remote set-url origin git@github.com:champand/pl-hackathon2025.git

# Push
git push -u origin claude/aws-multi-account-design-01D8vATHhW3mNaQw5ZtdKD15
```

## Step 4: Push Code to GitHub

### Push from Current Environment

```bash
cd /home/user/pl-hackathon2025

# Verify remote is set
git remote -v

# Check current branch
git branch

# Verify commit exists
git log --oneline -1

# Push to GitHub
git push -u origin claude/aws-multi-account-design-01D8vATHhW3mNaQw5ZtdKD15
```

### Expected Output

```
Enumerating objects: 26, done.
Counting objects: 100% (26/26), done.
Delta compression using up to 4 threads
Compressing objects: 100% (22/22), done.
Writing objects: 100% (26/26), 52.34 KiB | 5.23 MiB/s, done.
Total 26 (delta 2), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (2/2), done.
To https://github.com/champand/pl-hackathon2025.git
 * [new branch]      claude/aws-multi-account-design-01D8vATHhW3mNaQw5ZtdKD15 -> claude/aws-multi-account-design-01D8vATHhW3mNaQw5ZtdKD15
Branch 'claude/aws-multi-account-design-01D8vATHhW3mNaQw5ZtdKD15' set up to track remote branch 'claude/aws-multi-account-design-01D8vATHhW3mNaQw5ZtdKD15' from 'origin'.
```

## Step 5: Verify on GitHub

1. Go to https://github.com/champand/pl-hackathon2025
2. You should see a notification: **"claude/aws-multi-account-design-01D8vATHhW3mNaQw5ZtdKD15 had recent pushes"**
3. Click **Compare & pull request** (optional)
4. Or switch branches to view the new branch

## Troubleshooting

### Authentication Failed

**Error**: `Authentication failed for 'https://github.com/...'`

**Solutions**:
1. Verify token is correct (no extra spaces)
2. Check token hasn't expired
3. Ensure token has `repo` permissions
4. Try regenerating token

### Permission Denied

**Error**: `Permission denied (publickey)` (for SSH)

**Solutions**:
1. Verify SSH key is added to GitHub
2. Test SSH connection: `ssh -T git@github.com`
3. Check SSH agent is running: `ssh-add -l`

### Remote Already Exists

**Error**: `remote origin already exists`

**Solution**:
```bash
# Update existing remote
git remote set-url origin https://YOUR_TOKEN@github.com/champand/pl-hackathon2025.git
```

### Push Rejected

**Error**: `Updates were rejected because the remote contains work that you do not have locally`

**Solution**:
```bash
# Fetch remote changes first
git fetch origin

# Check what's in remote
git log origin/main --oneline

# If safe, force push (use with caution!)
git push -u origin claude/aws-multi-account-design-01D8vATHhW3mNaQw5ZtdKD15 --force

# Or rebase your changes
git pull --rebase origin main
git push -u origin claude/aws-multi-account-design-01D8vATHhW3mNaQw5ZtdKD15
```

## Quick Reference Commands

```bash
# Navigate to repository
cd /home/user/pl-hackathon2025

# Check status
git status
git log --oneline -5

# Configure authentication (choose one method)

## Method 1: Token in URL
git remote set-url origin https://YOUR_TOKEN@github.com/champand/pl-hackathon2025.git

## Method 2: SSH
git remote set-url origin git@github.com:champand/pl-hackathon2025.git

## Method 3: Credential helper (will prompt for token)
git config --global credential.helper store

# Push code
git push -u origin claude/aws-multi-account-design-01D8vATHhW3mNaQw5ZtdKD15

# Verify push
git ls-remote origin
```

## Security Best Practices

### ✅ DO:
- Use fine-grained tokens with minimal permissions
- Set token expiration (30-90 days)
- Store tokens in secure credential managers
- Use SSH keys for long-term access
- Delete tokens when no longer needed
- Use different tokens for different projects

### ❌ DON'T:
- Commit tokens to repositories
- Share tokens with others
- Use tokens in URLs in shared environments
- Set tokens to never expire
- Use classic tokens with full scope unless necessary
- Store tokens in plain text files

## Token Management

### View Your Tokens

1. GitHub → Settings → Developer settings → Personal access tokens
2. See all tokens, when they were created, and when they expire
3. Revoke tokens you no longer need

### Rotate Tokens Regularly

```bash
# When rotating token:
# 1. Generate new token on GitHub
# 2. Update git remote
git remote set-url origin https://NEW_TOKEN@github.com/champand/pl-hackathon2025.git
# 3. Revoke old token on GitHub
```

### Token Storage Options

1. **Git Credential Manager** (Best for desktop)
   - Securely stores credentials in OS keychain
   - Works on Windows, Mac, Linux

2. **Environment Variables** (Good for CI/CD)
   ```bash
   export GITHUB_TOKEN="your_token"
   git clone https://${GITHUB_TOKEN}@github.com/champand/pl-hackathon2025.git
   ```

3. **Secret Management Tools** (Best for production)
   - AWS Secrets Manager
   - HashiCorp Vault
   - Azure Key Vault

## Alternative: GitHub CLI

If you prefer using GitHub CLI:

```bash
# Install GitHub CLI
# Linux
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh

# Authenticate
gh auth login

# Push using gh
cd /home/user/pl-hackathon2025
git push -u origin claude/aws-multi-account-design-01D8vATHhW3mNaQw5ZtdKD15
```

## Need Help?

- **GitHub Docs**: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
- **Git Credential Manager**: https://github.com/GitCredentialManager/git-credential-manager
- **SSH Setup**: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

---

**Last Updated**: December 3, 2025
