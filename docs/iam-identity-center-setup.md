# IAM Identity Center (AWS SSO) Setup Guide for Hackathon

## Overview

This guide provides step-by-step instructions for configuring AWS IAM Identity Center (formerly AWS SSO) to provide secure, isolated access to hackathon team accounts.

## Architecture

```
IAM Identity Center (Organization Management Account)
├── Active Directory Groups
│   ├── hackathon-team-01
│   ├── hackathon-team-02
│   ├── ...
│   └── hackathon-team-25
├── Permission Sets
│   ├── HackathonAdministrator
│   └── HackathonReadOnly (Optional)
└── Account Assignments
    ├── Team 01 Account → hackathon-team-01 → HackathonAdministrator
    ├── Team 02 Account → hackathon-team-02 → HackathonAdministrator
    └── ...
```

## Prerequisites

1. AWS Organizations enabled
2. IAM Identity Center enabled in the Organization management account
3. Active Directory or IAM Identity Center directory configured
4. 25 hackathon AWS accounts created under the Hackathon OU

## Step 1: Create AD Groups (if using AD as Identity Source)

Create AD groups for each team:

```powershell
# PowerShell script to create AD groups
$teams = 1..25
foreach ($team in $teams) {
    $teamNumber = $team.ToString("00")
    $groupName = "hackathon-team-$teamNumber"
    $description = "AI Hackathon 2025 - Team $teamNumber"

    New-ADGroup -Name $groupName `
                -SamAccountName $groupName `
                -GroupCategory Security `
                -GroupScope Global `
                -Description $description `
                -Path "OU=HackathonTeams,OU=Groups,DC=example,DC=com"
}
```

## Step 2: Sync AD Groups to IAM Identity Center

1. Navigate to IAM Identity Center console
2. Go to **Settings** → **Identity source**
3. If using AD:
   - Select **Active Directory**
   - Click **Configure**
   - Select your AD directory
   - Enable automatic provisioning
4. Wait for sync to complete (check **Groups** section)

## Step 3: Create Permission Set - HackathonAdministrator

### Option A: Using AWS Console

1. Navigate to **IAM Identity Center** → **Permission sets**
2. Click **Create permission set**
3. Select **Custom permission set**
4. Configure:
   - **Name:** `HackathonAdministrator`
   - **Description:** `Administrative access for hackathon team accounts with guardrails`
   - **Session duration:** 8 hours (or as needed)

5. Add managed policies:
   - `arn:aws:iam::aws:policy/AdministratorAccess`

6. Add inline policy to enforce permission boundary:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "organizations:LeaveOrganization",
        "account:CloseAccount"
      ],
      "Resource": "*"
    }
  ]
}
```

7. Set **Permissions boundary:** (Optional, if you want additional safety)
   - Select **Customer managed policy**
   - Choose `HackathonPermissionBoundary` (must be created first in each account)

### Option B: Using AWS CLI

```bash
# Create permission set
aws sso-admin create-permission-set \
  --instance-arn arn:aws:sso:::instance/ssoins-XXXXXXXXXXXX \
  --name HackathonAdministrator \
  --description "Administrative access for hackathon teams" \
  --session-duration PT8H

# Get the permission set ARN from the output
PERMISSION_SET_ARN="arn:aws:sso:::permissionSet/ssoins-XXXXXXXXXXXX/ps-XXXXXXXXXXXX"

# Attach AdministratorAccess managed policy
aws sso-admin attach-managed-policy-to-permission-set \
  --instance-arn arn:aws:sso:::instance/ssoins-XXXXXXXXXXXX \
  --permission-set-arn $PERMISSION_SET_ARN \
  --managed-policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Add inline policy
cat > hackathon-admin-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "organizations:LeaveOrganization",
        "account:CloseAccount",
        "budgets:DeleteBudgetAction",
        "budgets:ModifyBudget"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws sso-admin put-inline-policy-to-permission-set \
  --instance-arn arn:aws:sso:::instance/ssoins-XXXXXXXXXXXX \
  --permission-set-arn $PERMISSION_SET_ARN \
  --inline-policy file://hackathon-admin-policy.json
```

## Step 4: Create Account Assignments

### Manual Assignment (Console)

For each team:
1. Navigate to **AWS accounts**
2. Select the team's account
3. Click **Assign users or groups**
4. Select **Groups**
5. Choose the corresponding group (e.g., `hackathon-team-01`)
6. Select permission set: `HackathonAdministrator`
7. Click **Submit**

### Automated Assignment (CLI Script)

```bash
#!/bin/bash

# Configuration
INSTANCE_ARN="arn:aws:sso:::instance/ssoins-XXXXXXXXXXXX"
PERMISSION_SET_ARN="arn:aws:sso:::permissionSet/ssoins-XXXXXXXXXXXX/ps-XXXXXXXXXXXX"
IDENTITY_STORE_ID="d-XXXXXXXXXX"

# Account mappings (replace with your actual account IDs)
declare -A TEAM_ACCOUNTS=(
  ["team-01"]="123456789012"
  ["team-02"]="123456789013"
  ["team-03"]="123456789014"
  # ... add all 25 teams
  ["team-25"]="123456789036"
)

# Get group IDs from Identity Center
for team in "${!TEAM_ACCOUNTS[@]}"; do
  echo "Processing $team..."

  # Get group ID
  GROUP_ID=$(aws identitystore list-groups \
    --identity-store-id $IDENTITY_STORE_ID \
    --filters AttributePath=DisplayName,AttributeValue=hackathon-$team \
    --query 'Groups[0].GroupId' \
    --output text)

  if [ "$GROUP_ID" != "None" ] && [ ! -z "$GROUP_ID" ]; then
    # Create account assignment
    aws sso-admin create-account-assignment \
      --instance-arn $INSTANCE_ARN \
      --target-id ${TEAM_ACCOUNTS[$team]} \
      --target-type AWS_ACCOUNT \
      --permission-set-arn $PERMISSION_SET_ARN \
      --principal-type GROUP \
      --principal-id $GROUP_ID

    echo "✓ Assigned $team to account ${TEAM_ACCOUNTS[$team]}"
  else
    echo "✗ Group hackathon-$team not found"
  fi

  sleep 2  # Rate limiting
done

echo "Account assignments complete!"
```

## Step 5: Create Optional Read-Only Permission Set

For cloud team observers or mentors:

```bash
# Create read-only permission set
aws sso-admin create-permission-set \
  --instance-arn arn:aws:sso:::instance/ssoins-XXXXXXXXXXXX \
  --name HackathonReadOnly \
  --description "Read-only access for hackathon support staff" \
  --session-duration PT4H

# Attach ViewOnlyAccess policy
aws sso-admin attach-managed-policy-to-permission-set \
  --instance-arn arn:aws:sso:::instance/ssoins-XXXXXXXXXXXX \
  --permission-set-arn $READONLY_PERMISSION_SET_ARN \
  --managed-policy-arn arn:aws:iam::aws:policy/job-function/ViewOnlyAccess
```

## Step 6: Configure Permission Set Session Tags

Add session tags to track user activity:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:TagSession",
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/Team": "team-*"
        }
      }
    }
  ]
}
```

## Step 7: User Access Instructions

### For Hackathon Participants

1. **Access URL:** Provide teams with the AWS access portal URL:
   ```
   https://your-org.awsapps.com/start
   ```

2. **Login Credentials:**
   - Username: `<AD-username>` or `<email>`
   - Password: `<AD-password>` or temporary password
   - MFA: Required (if configured)

3. **Account Selection:**
   - After login, users will see their assigned account
   - Click on the account name
   - Click "Management console" or use CLI credentials

### AWS CLI Configuration

```bash
# Install AWS CLI SSO
aws configure sso

# Configuration prompts:
# SSO start URL: https://your-org.awsapps.com/start
# SSO region: us-east-1 (or your IAM Identity Center region)
# Account ID: <team-account-id>
# Role name: HackathonAdministrator
# CLI default region: ap-south-1
# CLI output format: json

# Login
aws sso login --profile hackathon-team-01

# Test access
aws sts get-caller-identity --profile hackathon-team-01
```

## Step 8: Automation Script for All 25 Teams

Complete automation script:

```python
#!/usr/bin/env python3

import boto3
import time
from typing import Dict, List

class HackathonSSOSetup:
    def __init__(self, instance_arn: str, identity_store_id: str):
        self.sso_admin = boto3.client('sso-admin')
        self.identitystore = boto3.client('identitystore')
        self.instance_arn = instance_arn
        self.identity_store_id = identity_store_id

    def create_permission_set(self, name: str, description: str) -> str:
        """Create a permission set"""
        response = self.sso_admin.create_permission_set(
            InstanceArn=self.instance_arn,
            Name=name,
            Description=description,
            SessionDuration='PT8H'
        )
        return response['PermissionSet']['PermissionSetArn']

    def attach_managed_policy(self, permission_set_arn: str, policy_arn: str):
        """Attach a managed policy to permission set"""
        self.sso_admin.attach_managed_policy_to_permission_set(
            InstanceArn=self.instance_arn,
            PermissionSetArn=permission_set_arn,
            ManagedPolicyArn=policy_arn
        )

    def get_group_id(self, group_name: str) -> str:
        """Get group ID from group name"""
        response = self.identitystore.list_groups(
            IdentityStoreId=self.identity_store_id,
            Filters=[
                {
                    'AttributePath': 'DisplayName',
                    'AttributeValue': group_name
                }
            ]
        )
        if response['Groups']:
            return response['Groups'][0]['GroupId']
        return None

    def create_account_assignment(self, account_id: str, group_id: str,
                                 permission_set_arn: str):
        """Create account assignment"""
        self.sso_admin.create_account_assignment(
            InstanceArn=self.instance_arn,
            TargetId=account_id,
            TargetType='AWS_ACCOUNT',
            PermissionSetArn=permission_set_arn,
            PrincipalType='GROUP',
            PrincipalId=group_id
        )

    def setup_all_teams(self, team_accounts: Dict[str, str],
                       permission_set_arn: str):
        """Setup SSO for all teams"""
        for team_name, account_id in team_accounts.items():
            print(f"Setting up {team_name}...")

            # Get group ID
            group_name = f"hackathon-{team_name}"
            group_id = self.get_group_id(group_name)

            if not group_id:
                print(f"  ✗ Group {group_name} not found, skipping")
                continue

            # Create assignment
            try:
                self.create_account_assignment(
                    account_id=account_id,
                    group_id=group_id,
                    permission_set_arn=permission_set_arn
                )
                print(f"  ✓ Assigned {group_name} to account {account_id}")
            except Exception as e:
                print(f"  ✗ Error: {str(e)}")

            time.sleep(2)  # Rate limiting

def main():
    # Configuration
    INSTANCE_ARN = "arn:aws:sso:::instance/ssoins-XXXXXXXXXXXX"
    IDENTITY_STORE_ID = "d-XXXXXXXXXX"

    # Team account mappings
    team_accounts = {
        f"team-{i:02d}": f"12345678{i:04d}"
        for i in range(1, 26)
    }

    # Initialize
    setup = HackathonSSOSetup(INSTANCE_ARN, IDENTITY_STORE_ID)

    # Create permission set
    print("Creating permission set...")
    permission_set_arn = setup.create_permission_set(
        name="HackathonAdministrator",
        description="Admin access for hackathon teams"
    )
    print(f"✓ Created: {permission_set_arn}")

    # Attach policy
    print("Attaching AdministratorAccess policy...")
    setup.attach_managed_policy(
        permission_set_arn=permission_set_arn,
        policy_arn="arn:aws:iam::aws:policy/AdministratorAccess"
    )
    print("✓ Policy attached")

    # Setup all teams
    print("\nSetting up team assignments...")
    setup.setup_all_teams(team_accounts, permission_set_arn)

    print("\n✓ Setup complete!")

if __name__ == "__main__":
    main()
```

## Best Practices

### 1. **Group Naming Convention**
- Use consistent naming: `hackathon-team-XX`
- Include year if recurring: `hackathon-2025-team-XX`

### 2. **Session Duration**
- Set reasonable session duration (4-8 hours)
- Balance between security and user convenience

### 3. **MFA Enforcement**
- Enable MFA requirement in Identity Center settings
- Consider conditional MFA based on risk

### 4. **Monitoring**
- Enable CloudTrail for SSO events
- Monitor sign-in activities
- Set up alerts for unusual access patterns

### 5. **Cleanup**
- Document all account assignments
- Plan for post-hackathon deprovisioning
- Archive access logs before cleanup

## Troubleshooting

### Users Can't See Their Account
1. Verify group membership in AD/Identity Center
2. Check account assignment was created successfully
3. Verify permission set is provisioned
4. Check user has completed MFA setup (if required)

### Permission Denied Errors
1. Verify SCPs are not blocking the action
2. Check permission boundary is not overly restrictive
3. Verify session hasn't expired
4. Check for explicit denies in policies

### Assignment Failures
1. Check account is in correct OU
2. Verify permission set exists and is valid
3. Check for concurrent modification errors
4. Review CloudTrail for detailed error messages

## Post-Hackathon Cleanup

```bash
#!/bin/bash
# Cleanup script to remove all assignments

INSTANCE_ARN="arn:aws:sso:::instance/ssoins-XXXXXXXXXXXX"
PERMISSION_SET_ARN="arn:aws:sso:::permissionSet/ssoins-XXXXXXXXXXXX/ps-XXXXXXXXXXXX"

# List all account assignments
aws sso-admin list-account-assignments \
  --instance-arn $INSTANCE_ARN \
  --account-id <account-id> \
  --permission-set-arn $PERMISSION_SET_ARN \
  --query 'AccountAssignments[*]' \
  --output json | \
  jq -r '.[] | [.AccountId, .PrincipalId] | @tsv' | \
  while read account_id principal_id; do
    echo "Removing assignment from $account_id for $principal_id"
    aws sso-admin delete-account-assignment \
      --instance-arn $INSTANCE_ARN \
      --target-id $account_id \
      --target-type AWS_ACCOUNT \
      --permission-set-arn $PERMISSION_SET_ARN \
      --principal-type GROUP \
      --principal-id $principal_id
  done
```

## Additional Resources

- [IAM Identity Center Documentation](https://docs.aws.amazon.com/singlesignon/latest/userguide/)
- [Permission Sets Best Practices](https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsets.html)
- [AWS SSO CLI Configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html)
