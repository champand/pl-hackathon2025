# Hackathon 2025 - Deployment Guide

This guide provides step-by-step instructions for deploying all hackathon infrastructure components.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Pre-Deployment Checklist](#pre-deployment-checklist)
4. [Deployment Steps](#deployment-steps)
5. [Validation](#validation)
6. [Post-Deployment](#post-deployment)
7. [Troubleshooting](#troubleshooting)
8. [Rollback Procedures](#rollback-procedures)

## Prerequisites

### Required Tools

- **AWS CLI** (version 2.x or higher)
  ```bash
  aws --version
  ```

- **jq** (JSON processor)
  ```bash
  jq --version
  ```

- **git**
  ```bash
  git --version
  ```

- **Python 3.8+** (for automation scripts)
  ```bash
  python3 --version
  ```

### Required AWS Permissions

The deployment user/role must have:

- **AWS Organizations**: Full access
- **IAM Identity Center**: Full access
- **CloudFormation**: Full access
- **AWS Config**: Full access
- **AWS Budgets**: Full access
- **STS**: AssumeRole permissions for all hackathon accounts

### AWS Account Structure

```
Root Organization
└── Hackathon OU (ou-xxxx-xxxxxxxx)
    ├── team-01 Account (123456789012)
    ├── team-02 Account (123456789013)
    ├── ...
    └── team-25 Account (123456789036)
```

## Architecture Overview

### Components to Deploy

1. **Service Control Policy (SCP)** - Organization level
2. **IAM Identity Center Configuration** - Organization level
3. **Budget Alerts** - Per account
4. **AWS Config Setup** - Per account
5. **Permission Boundaries** - Per account (optional)
6. **CloudFormation Hooks** - Per account (optional)

### Deployment Order

```
1. Create OU Structure
2. Deploy SCP to Hackathon OU
3. Configure IAM Identity Center
4. Deploy Budget Alerts (all accounts)
5. Deploy AWS Config (all accounts)
6. Enable Config Recorders
7. Deploy Permission Boundaries (optional)
8. Configure CloudFormation Hooks (optional)
9. Validate and test
```

## Pre-Deployment Checklist

- [ ] All 25 hackathon accounts created
- [ ] Accounts organized under dedicated Hackathon OU
- [ ] AD groups created for each team (if using AD)
- [ ] Email addresses collected for all teams
- [ ] Budget limits approved
- [ ] Cloud Team email configured
- [ ] Cross-account access role exists in all accounts
- [ ] Configuration files prepared
- [ ] Testing plan documented

## Deployment Steps

### Step 1: Clone Repository

```bash
git clone https://github.com/your-org/pl-hackathon2025.git
cd pl-hackathon2025
```

### Step 2: Configure Accounts

1. Copy the example configuration:
   ```bash
   cp deployment/config/accounts.json.example deployment/config/accounts.json
   ```

2. Edit `deployment/config/accounts.json` with actual account IDs:
   ```json
   {
     "cloudTeamEmail": "cloud-team@example.com",
     "assumeRoleName": "OrganizationAccountAccessRole",
     "accounts": [
       {
         "teamName": "team-01",
         "accountId": "123456789012",
         "budgetLimit": 500,
         "teamEmail": "team-01@hackathon.example.com"
       }
     ]
   }
   ```

### Step 3: Deploy Service Control Policy

1. Identify your Hackathon OU ID:
   ```bash
   aws organizations list-organizational-units-for-parent \
     --parent-id r-xxxx \
     --query 'OrganizationalUnits[?Name==`Hackathon`].Id' \
     --output text
   ```

2. Deploy the SCP:
   ```bash
   cd deployment/scripts
   chmod +x deploy-scp.sh
   ./deploy-scp.sh --ou-id ou-xxxx-xxxxxxxx
   ```

3. Verify SCP attachment:
   ```bash
   aws organizations list-policies-for-target \
     --target-id ou-xxxx-xxxxxxxx \
     --filter SERVICE_CONTROL_POLICY
   ```

### Step 4: Configure IAM Identity Center

Follow the detailed guide: [IAM Identity Center Setup](../../docs/iam-identity-center-setup.md)

**Quick Steps:**

1. Create permission set:
   ```bash
   python3 deployment/scripts/setup-sso.py create-permission-set
   ```

2. Create account assignments:
   ```bash
   python3 deployment/scripts/setup-sso.py assign-all-accounts \
     --config deployment/config/accounts.json
   ```

3. Verify assignments:
   ```bash
   aws sso-admin list-account-assignments \
     --instance-arn arn:aws:sso:::instance/ssoins-XXXXXXXXXXXX \
     --account-id 123456789012 \
     --permission-set-arn arn:aws:sso:::permissionSet/...
   ```

### Step 5: Deploy Budget Alerts

Deploy budget monitoring to all accounts:

```bash
cd deployment/scripts
chmod +x deploy-to-all-accounts.sh
./deploy-to-all-accounts.sh
```

**What this does:**
- Assumes role in each account
- Deploys budget CloudFormation stack
- Creates SNS topics and subscriptions
- Configures budget alerts

**Monitor Progress:**
```bash
# Check stack status
aws cloudformation describe-stacks \
  --stack-name team-01-budget-alerts \
  --query 'Stacks[0].StackStatus'
```

### Step 6: Deploy AWS Config

The deployment script from Step 5 also deploys AWS Config. To deploy Config separately:

```bash
# Deploy to specific account
aws cloudformation deploy \
  --template-file cloudformation/config-monitoring/aws-config-setup.yaml \
  --stack-name team-01-config-monitoring \
  --parameter-overrides \
    TeamName=team-01 \
    ConfigBucketName=team-01-config-123456789012-ap-south-1 \
    CloudTeamEmail=cloud-team@example.com \
  --capabilities CAPABILITY_NAMED_IAM
```

**Enable Config Recorder:**
```bash
aws configservice start-configuration-recorder \
  --configuration-recorder-name team-01-config-recorder
```

### Step 7: Deploy Permission Boundaries (Optional)

1. Create IAM policy in each account:
   ```bash
   aws iam create-policy \
     --policy-name HackathonPermissionBoundary \
     --policy-document file://policies/iam-boundaries/hackathon-permission-boundary.json
   ```

2. Update SSO permission set to enforce boundary (if needed)

### Step 8: Configure CloudFormation Hooks (Optional)

**Note:** CloudFormation Guard Hooks require additional setup.

1. Upload Guard rules to S3:
   ```bash
   aws s3 cp cloudformation/resource-limits/cfn-guard-rules.guard \
     s3://your-guard-rules-bucket/cfn-guard-rules.guard
   ```

2. Deploy Hook configuration:
   ```bash
   aws cloudformation deploy \
     --template-file cloudformation/resource-limits/cfn-hooks-config.yaml \
     --stack-name cfn-guard-hooks
   ```

## Validation

### 1. Verify SCP Enforcement

Test that SCPs are blocking prohibited actions:

```bash
# Try to close account (should fail)
aws account close-account --account-id 123456789012
# Expected: AccessDenied

# Try to create resource in wrong region (should fail)
aws ec2 run-instances \
  --image-id ami-12345678 \
  --instance-type t2.micro \
  --region us-east-1
# Expected: AccessDenied
```

### 2. Verify Budget Alerts

```bash
# Check budget exists
aws budgets describe-budget \
  --account-id 123456789012 \
  --budget-name team-01-monthly-budget

# Verify SNS subscriptions
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:ap-south-1:123456789012:team-01-budget-alerts
```

### 3. Verify AWS Config

```bash
# Check Config recorder status
aws configservice describe-configuration-recorder-status \
  --configuration-recorder-names team-01-config-recorder

# List Config rules
aws configservice describe-config-rules \
  --query 'ConfigRules[*].ConfigRuleName'
```

### 4. Verify IAM Identity Center Access

1. Have a test user log in to AWS access portal
2. Verify they can see their assigned account
3. Test console access
4. Test CLI access with SSO

### 5. Test Resource Limits

Deploy a test CloudFormation stack with a prohibited resource:

```yaml
# test-large-instance.yaml
Resources:
  TestInstance:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: m5.16xlarge  # Should be blocked
      ImageId: ami-0c55b159cbfafe1f0
```

```bash
aws cloudformation create-stack \
  --stack-name test-limits \
  --template-body file://test-large-instance.yaml
# Expected: Should fail if guards are active
```

## Post-Deployment

### 1. Document Access Details

Create team access documentation:

```markdown
# Team Access Guide

**AWS Access Portal:** https://your-org.awsapps.com/start
**Account ID:** 123456789012
**Region:** ap-south-1
**Budget Limit:** $500/month

## Getting Started
1. Log in to access portal
2. Click on your team account
3. Click "Management console"
```

### 2. Set Up Monitoring Dashboard

1. Create CloudWatch dashboard for all accounts
2. Configure budget alert aggregation
3. Set up Config compliance dashboard

### 3. Create Runbook

Document common operations:
- How to increase budget
- How to troubleshoot access issues
- How to handle quota requests
- Emergency contact procedures

### 4. Schedule Review Meeting

- Review all configurations
- Test emergency procedures
- Verify monitoring alerts
- Confirm support coverage

## Troubleshooting

### SCP Not Applying

**Symptom:** Users can perform actions that should be blocked

**Solutions:**
1. Verify SCP is attached to OU:
   ```bash
   aws organizations list-policies-for-target --target-id ou-xxxx
   ```
2. Check account is in correct OU:
   ```bash
   aws organizations list-parents --child-id 123456789012
   ```
3. Wait 5-10 minutes for SCP propagation

### Budget Alerts Not Sending

**Symptom:** No budget alert emails received

**Solutions:**
1. Check SNS subscription confirmation:
   ```bash
   aws sns list-subscriptions-by-topic --topic-arn <topic-arn>
   ```
2. Verify email is confirmed (check spam folder)
3. Test SNS topic:
   ```bash
   aws sns publish --topic-arn <topic-arn> --message "Test"
   ```

### Config Recorder Not Running

**Symptom:** Config rules show no evaluations

**Solutions:**
1. Check recorder status:
   ```bash
   aws configservice describe-configuration-recorder-status
   ```
2. Start recorder:
   ```bash
   aws configservice start-configuration-recorder \
     --configuration-recorder-name <name>
   ```
3. Verify S3 bucket permissions

### SSO Access Denied

**Symptom:** Users can't access assigned accounts

**Solutions:**
1. Verify group membership in Identity Center
2. Check account assignment exists
3. Verify permission set is provisioned
4. Check user has completed MFA setup (if required)

### CloudFormation Deployment Failures

**Symptom:** Stack deployment fails

**Solutions:**
1. Check CloudFormation events:
   ```bash
   aws cloudformation describe-stack-events --stack-name <name>
   ```
2. Verify IAM permissions
3. Check parameter values
4. Review SCP for blocks

## Rollback Procedures

### Rollback SCP

1. Detach SCP from OU:
   ```bash
   aws organizations detach-policy \
     --policy-id p-xxxx \
     --target-id ou-xxxx
   ```

2. Delete SCP (if needed):
   ```bash
   aws organizations delete-policy --policy-id p-xxxx
   ```

### Rollback Budget Stacks

```bash
# Delete budget stack
aws cloudformation delete-stack --stack-name team-01-budget-alerts

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --stack-name team-01-budget-alerts
```

### Rollback Config Stacks

```bash
# Stop recorder first
aws configservice stop-configuration-recorder \
  --configuration-recorder-name team-01-config-recorder

# Delete stack
aws cloudformation delete-stack --stack-name team-01-config-monitoring
```

### Rollback IAM Identity Center Assignments

```bash
# Delete account assignment
aws sso-admin delete-account-assignment \
  --instance-arn <instance-arn> \
  --target-id <account-id> \
  --target-type AWS_ACCOUNT \
  --permission-set-arn <permission-set-arn> \
  --principal-type GROUP \
  --principal-id <group-id>
```

## Best Practices

1. **Test in Non-Production First**
   - Use a test account to validate all templates
   - Test SCP policies carefully

2. **Incremental Deployment**
   - Deploy to 2-3 accounts first
   - Validate before deploying to all 25

3. **Monitor During Deployment**
   - Watch CloudFormation events
   - Check email for SNS confirmations
   - Verify Config recorder starts

4. **Document Everything**
   - Keep deployment logs
   - Document any issues and resolutions
   - Update runbooks with lessons learned

5. **Communication**
   - Notify teams before deployment
   - Provide clear access instructions
   - Set up support channels

## Support Contacts

- **Cloud Team Email:** cloud-team@example.com
- **AWS Support:** [AWS Support Center](https://console.aws.amazon.com/support/)
- **Emergency Escalation:** [Define escalation path]

## Additional Resources

- [AWS Organizations Best Practices](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_best-practices.html)
- [IAM Identity Center Documentation](https://docs.aws.amazon.com/singlesignon/latest/userguide/)
- [AWS Config Documentation](https://docs.aws.amazon.com/config/latest/developerguide/)
- [AWS Budgets Documentation](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html)
