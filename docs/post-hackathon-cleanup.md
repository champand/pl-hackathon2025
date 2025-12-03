# Post-Hackathon Cleanup Guide

## Overview

This guide provides comprehensive procedures for cleaning up AWS resources after the hackathon concludes.

## Cleanup Timeline

### Recommended Schedule

```
Day 0 (Last Day of Hackathon):
├── Announce cleanup timeline to all teams
├── Request teams to document resources they want to preserve
└── Take snapshots/backups of requested resources

Day 1-3 (Grace Period):
├── Teams can access accounts (read-only recommended)
├── Export data, logs, and documentation
└── Verify all important data is backed up

Day 4-7 (Cleanup Phase):
├── Generate final cost reports
├── Archive CloudTrail logs
├── Delete resources systematically
└── Verify all resources are removed

Day 8+ (Decommission):
├── Remove IAM Identity Center assignments
├── Detach/delete SCPs
├── Close or suspend accounts (optional)
└── Archive documentation
```

## Pre-Cleanup Checklist

- [ ] Notify all teams of cleanup schedule
- [ ] Generate final cost reports per team
- [ ] Archive CloudTrail logs
- [ ] Back up AWS Config data
- [ ] Export any competition artifacts
- [ ] Document lessons learned
- [ ] Take screenshots of dashboards

## Phase 1: Data Preservation

### 1. Generate Cost Reports

```bash
#!/bin/bash
# Generate final cost report for all teams

OUTPUT_DIR="./cost-reports"
mkdir -p $OUTPUT_DIR

START_DATE="2025-12-01"
END_DATE="2025-12-31"

# Get list of all teams
TEAMS=$(jq -r '.accounts[].teamName' deployment/config/accounts.json)

for team in $TEAMS; do
  echo "Generating cost report for $team..."

  aws ce get-cost-and-usage \
    --time-period Start=$START_DATE,End=$END_DATE \
    --granularity DAILY \
    --metrics UnblendedCost \
    --group-by Type=DIMENSION,Key=SERVICE \
    --filter file://- <<EOF > "${OUTPUT_DIR}/${team}-cost-report.json"
{
  "Tags": {
    "Key": "Team",
    "Values": ["$team"]
  }
}
EOF

  echo "✓ Report saved: ${OUTPUT_DIR}/${team}-cost-report.json"
done

# Generate summary report
echo "Generating summary report..."
aws ce get-cost-and-usage \
  --time-period Start=$START_DATE,End=$END_DATE \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Team \
  > "${OUTPUT_DIR}/hackathon-summary.json"

echo "✓ All cost reports generated in $OUTPUT_DIR"
```

### 2. Archive CloudTrail Logs

```bash
#!/bin/bash
# Archive CloudTrail logs for all accounts

ARCHIVE_BUCKET="your-archive-bucket"
START_DATE="2025-12-01"
END_DATE="2025-12-31"

# Get list of accounts
ACCOUNTS=$(jq -r '.accounts[] | "\(.teamName):\(.accountId)"' deployment/config/accounts.json)

for account_info in $ACCOUNTS; do
  team_name=$(echo $account_info | cut -d: -f1)
  account_id=$(echo $account_info | cut -d: -f2)

  echo "Archiving CloudTrail logs for $team_name ($account_id)..."

  # Copy CloudTrail logs to archive bucket
  aws s3 sync \
    "s3://aws-cloudtrail-logs-${account_id}-ap-south-1/AWSLogs/${account_id}/" \
    "s3://${ARCHIVE_BUCKET}/hackathon-2025/cloudtrail/${team_name}/" \
    --exclude "*" \
    --include "2025/12/*" \
    --storage-class GLACIER

  echo "✓ Archived logs for $team_name"
done
```

### 3. Export AWS Config Data

```bash
#!/bin/bash
# Export AWS Config snapshots

ACCOUNTS=$(jq -r '.accounts[] | "\(.teamName):\(.accountId)"' deployment/config/accounts.json)

for account_info in $ACCOUNTS; do
  team_name=$(echo $account_info | cut -d: -f1)
  account_id=$(echo $account_info | cut -d: -f2)

  echo "Exporting Config snapshot for $team_name..."

  # Assume role in account
  credentials=$(aws sts assume-role \
    --role-arn "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" \
    --role-session-name "config-export" \
    --duration-seconds 3600)

  export AWS_ACCESS_KEY_ID=$(echo $credentials | jq -r '.Credentials.AccessKeyId')
  export AWS_SECRET_ACCESS_KEY=$(echo $credentials | jq -r '.Credentials.SecretAccessKey')
  export AWS_SESSION_TOKEN=$(echo $credentials | jq -r '.Credentials.SessionToken')

  # Trigger config snapshot
  aws configservice deliver-config-snapshot \
    --delivery-channel-name "${team_name}-delivery-channel"

  # Clear credentials
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

  echo "✓ Config snapshot delivered for $team_name"
done
```

### 4. Export Resource Inventory

```bash
#!/bin/bash
# Generate resource inventory for each account

OUTPUT_DIR="./resource-inventory"
mkdir -p $OUTPUT_DIR

ACCOUNTS=$(jq -r '.accounts[] | "\(.teamName):\(.accountId)"' deployment/config/accounts.json)

for account_info in $ACCOUNTS; do
  team_name=$(echo $account_info | cut -d: -f1)
  account_id=$(echo $account_info | cut -d: -f2)

  echo "Generating resource inventory for $team_name..."

  # Assume role
  credentials=$(aws sts assume-role \
    --role-arn "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" \
    --role-session-name "inventory" \
    --duration-seconds 3600)

  export AWS_ACCESS_KEY_ID=$(echo $credentials | jq -r '.Credentials.AccessKeyId')
  export AWS_SECRET_ACCESS_KEY=$(echo $credentials | jq -r '.Credentials.SecretAccessKey')
  export AWS_SESSION_TOKEN=$(echo $credentials | jq -r '.Credentials.SessionToken')

  # Get all resources
  aws resourcegroupstaggingapi get-resources \
    --region ap-south-1 \
    --resource-type-filters \
      ec2:instance \
      rds:db \
      s3:bucket \
      dynamodb:table \
      lambda:function \
      sagemaker:notebook-instance \
    > "${OUTPUT_DIR}/${team_name}-inventory.json"

  # Clear credentials
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

  echo "✓ Inventory saved: ${OUTPUT_DIR}/${team_name}-inventory.json"
done
```

## Phase 2: Resource Deletion

### Automated Cleanup Script

```bash
#!/bin/bash
###############################################################################
# Automated Resource Cleanup Script
# WARNING: This script will delete resources. Use with caution!
###############################################################################

set -e

# Configuration
DRY_RUN=true  # Set to false to actually delete resources
REGION="ap-south-1"

log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1"
}

# Delete EC2 resources
cleanup_ec2() {
    local account_id=$1
    local team_name=$2

    log_info "Cleaning up EC2 resources for $team_name..."

    # Terminate instances
    instance_ids=$(aws ec2 describe-instances \
        --region $REGION \
        --filters "Name=tag:Team,Values=$team_name" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text)

    if [ -n "$instance_ids" ]; then
        log_info "Found instances: $instance_ids"
        if [ "$DRY_RUN" = false ]; then
            aws ec2 terminate-instances --instance-ids $instance_ids --region $REGION
            log_info "✓ Terminated EC2 instances"
        else
            log_warn "DRY RUN: Would terminate instances: $instance_ids"
        fi
    fi

    # Delete volumes (after instances are terminated)
    sleep 60  # Wait for instances to terminate

    volume_ids=$(aws ec2 describe-volumes \
        --region $REGION \
        --filters "Name=tag:Team,Values=$team_name" \
        --query 'Volumes[?State==`available`].VolumeId' \
        --output text)

    if [ -n "$volume_ids" ]; then
        if [ "$DRY_RUN" = false ]; then
            for vol in $volume_ids; do
                aws ec2 delete-volume --volume-id $vol --region $REGION || true
            done
            log_info "✓ Deleted EBS volumes"
        else
            log_warn "DRY RUN: Would delete volumes: $volume_ids"
        fi
    fi

    # Delete security groups (except default)
    sg_ids=$(aws ec2 describe-security-groups \
        --region $REGION \
        --filters "Name=tag:Team,Values=$team_name" \
        --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
        --output text)

    if [ -n "$sg_ids" ]; then
        if [ "$DRY_RUN" = false ]; then
            for sg in $sg_ids; do
                aws ec2 delete-security-group --group-id $sg --region $REGION || true
            done
            log_info "✓ Deleted security groups"
        else
            log_warn "DRY RUN: Would delete security groups: $sg_ids"
        fi
    fi
}

# Delete RDS resources
cleanup_rds() {
    local team_name=$1

    log_info "Cleaning up RDS resources for $team_name..."

    # Delete DB instances
    db_instances=$(aws rds describe-db-instances \
        --region $REGION \
        --query "DBInstances[?contains(TagList[?Key=='Team'].Value, '$team_name')].DBInstanceIdentifier" \
        --output text)

    if [ -n "$db_instances" ]; then
        if [ "$DRY_RUN" = false ]; then
            for db in $db_instances; do
                aws rds delete-db-instance \
                    --db-instance-identifier $db \
                    --skip-final-snapshot \
                    --region $REGION || true
            done
            log_info "✓ Deleted RDS instances"
        else
            log_warn "DRY RUN: Would delete RDS instances: $db_instances"
        fi
    fi
}

# Delete S3 buckets
cleanup_s3() {
    local team_name=$1

    log_info "Cleaning up S3 buckets for $team_name..."

    # List buckets with team tag
    buckets=$(aws s3api list-buckets --query 'Buckets[*].Name' --output text)

    for bucket in $buckets; do
        tags=$(aws s3api get-bucket-tagging --bucket $bucket 2>/dev/null || echo "")

        if echo "$tags" | grep -q "$team_name"; then
            log_info "Found bucket: $bucket"

            if [ "$DRY_RUN" = false ]; then
                # Empty bucket first
                aws s3 rm s3://$bucket --recursive || true
                # Delete bucket
                aws s3api delete-bucket --bucket $bucket || true
                log_info "✓ Deleted bucket: $bucket"
            else
                log_warn "DRY RUN: Would delete bucket: $bucket"
            fi
        fi
    done
}

# Delete Lambda functions
cleanup_lambda() {
    local team_name=$1

    log_info "Cleaning up Lambda functions for $team_name..."

    functions=$(aws lambda list-functions \
        --region $REGION \
        --query "Functions[*].FunctionName" \
        --output text)

    for func in $functions; do
        tags=$(aws lambda list-tags --resource $(aws lambda get-function --function-name $func --query 'Configuration.FunctionArn' --output text) 2>/dev/null || echo "")

        if echo "$tags" | grep -q "$team_name"; then
            if [ "$DRY_RUN" = false ]; then
                aws lambda delete-function --function-name $func --region $REGION || true
                log_info "✓ Deleted function: $func"
            else
                log_warn "DRY RUN: Would delete function: $func"
            fi
        fi
    done
}

# Main cleanup function
cleanup_account() {
    local account_id=$1
    local team_name=$2

    log_info "========================================="
    log_info "Cleaning up account: $team_name ($account_id)"
    log_info "========================================="

    # Assume role
    credentials=$(aws sts assume-role \
        --role-arn "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" \
        --role-session-name "cleanup" \
        --duration-seconds 3600)

    export AWS_ACCESS_KEY_ID=$(echo $credentials | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo $credentials | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo $credentials | jq -r '.Credentials.SessionToken')

    # Run cleanup functions
    cleanup_ec2 "$account_id" "$team_name"
    cleanup_rds "$team_name"
    cleanup_s3 "$team_name"
    cleanup_lambda "$team_name"

    # Clear credentials
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

    log_info "Completed cleanup for $team_name"
}

# Main execution
main() {
    if [ "$DRY_RUN" = true ]; then
        log_warn "========================================="
        log_warn "DRY RUN MODE - No resources will be deleted"
        log_warn "Set DRY_RUN=false to actually delete resources"
        log_warn "========================================="
    fi

    # Load accounts
    ACCOUNTS=$(jq -r '.accounts[] | "\(.teamName):\(.accountId)"' deployment/config/accounts.json)

    for account_info in $ACCOUNTS; do
        team_name=$(echo $account_info | cut -d: -f1)
        account_id=$(echo $account_info | cut -d: -f2)

        cleanup_account "$account_id" "$team_name"

        sleep 2
    done

    log_info "========================================="
    log_info "Cleanup complete!"
    log_info "========================================="
}

main "$@"
```

### Manual Cleanup Checklist

For each account, verify deletion of:

- [ ] EC2 Instances
- [ ] EBS Volumes
- [ ] Elastic IPs
- [ ] Load Balancers
- [ ] Auto Scaling Groups
- [ ] RDS Instances
- [ ] DynamoDB Tables
- [ ] S3 Buckets
- [ ] Lambda Functions
- [ ] SageMaker Notebooks
- [ ] SageMaker Endpoints
- [ ] EKS Clusters
- [ ] OpenSearch Domains
- [ ] ElastiCache Clusters
- [ ] VPCs (and associated resources)

## Phase 3: Infrastructure Cleanup

### 1. Delete CloudFormation Stacks

```bash
#!/bin/bash
# Delete all hackathon CloudFormation stacks

ACCOUNTS=$(jq -r '.accounts[] | "\(.teamName):\(.accountId)"' deployment/config/accounts.json)

for account_info in $ACCOUNTS; do
  team_name=$(echo $account_info | cut -d: -f1)
  account_id=$(echo $account_info | cut -d: -f2)

  echo "Deleting CloudFormation stacks for $team_name..."

  # Assume role
  credentials=$(aws sts assume-role \
    --role-arn "arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole" \
    --role-session-name "cleanup" \
    --duration-seconds 3600)

  export AWS_ACCESS_KEY_ID=$(echo $credentials | jq -r '.Credentials.AccessKeyId')
  export AWS_SECRET_ACCESS_KEY=$(echo $credentials | jq -r '.Credentials.SecretAccessKey')
  export AWS_SESSION_TOKEN=$(echo $credentials | jq -r '.Credentials.SessionToken')

  # Stop Config recorder first
  aws configservice stop-configuration-recorder \
    --configuration-recorder-name "${team_name}-config-recorder" || true

  # Delete Config stack
  aws cloudformation delete-stack \
    --stack-name "${team_name}-config-monitoring"

  # Delete Budget stack
  aws cloudformation delete-stack \
    --stack-name "${team_name}-budget-alerts"

  # Clear credentials
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

  echo "✓ Deleted stacks for $team_name"
done
```

### 2. Remove IAM Identity Center Assignments

```bash
#!/bin/bash
# Remove all account assignments

INSTANCE_ARN="arn:aws:sso:::instance/ssoins-XXXXXXXXXXXX"
PERMISSION_SET_ARN="arn:aws:sso:::permissionSet/ssoins-XXXXXXXXXXXX/ps-XXXXXXXXXXXX"
IDENTITY_STORE_ID="d-XXXXXXXXXX"

ACCOUNTS=$(jq -r '.accounts[] | "\(.teamName):\(.accountId)"' deployment/config/accounts.json)

for account_info in $ACCOUNTS; do
  team_name=$(echo $account_info | cut -d: -f1)
  account_id=$(echo $account_info | cut -d: -f2)

  echo "Removing SSO assignment for $team_name..."

  # Get group ID
  group_id=$(aws identitystore list-groups \
    --identity-store-id $IDENTITY_STORE_ID \
    --filters AttributePath=DisplayName,AttributeValue=hackathon-$team_name \
    --query 'Groups[0].GroupId' \
    --output text)

  if [ "$group_id" != "None" ]; then
    # Delete assignment
    aws sso-admin delete-account-assignment \
      --instance-arn $INSTANCE_ARN \
      --target-id $account_id \
      --target-type AWS_ACCOUNT \
      --permission-set-arn $PERMISSION_SET_ARN \
      --principal-type GROUP \
      --principal-id $group_id

    echo "✓ Removed assignment for $team_name"
  fi
done
```

### 3. Detach and Delete SCP

```bash
#!/bin/bash
# Detach SCP from Hackathon OU

OU_ID="ou-xxxx-xxxxxxxx"
POLICY_NAME="HackathonGuardrails"

# Get policy ID
POLICY_ID=$(aws organizations list-policies \
  --filter SERVICE_CONTROL_POLICY \
  --query "Policies[?Name=='$POLICY_NAME'].Id" \
  --output text)

if [ -n "$POLICY_ID" ]; then
  echo "Detaching SCP from OU..."
  aws organizations detach-policy \
    --policy-id $POLICY_ID \
    --target-id $OU_ID

  echo "Deleting SCP..."
  aws organizations delete-policy --policy-id $POLICY_ID

  echo "✓ SCP removed"
fi
```

## Phase 4: Account Decommissioning

### Option A: Suspend Accounts

```bash
# Suspend accounts (keeps data, stops billing for most services)
ACCOUNTS=$(jq -r '.accounts[].accountId' deployment/config/accounts.json)

for account_id in $ACCOUNTS; do
  echo "Suspending account: $account_id"
  aws organizations suspend-account --account-id $account_id
done
```

### Option B: Close Accounts

**⚠️ WARNING: This action is irreversible!**

```bash
# Close accounts permanently
# Only do this if you're absolutely sure!

ACCOUNTS=$(jq -r '.accounts[].accountId' deployment/config/accounts.json)

for account_id in $ACCOUNTS; do
  echo "Closing account: $account_id"
  read -p "Are you sure? Type 'YES' to confirm: " confirm
  if [ "$confirm" == "YES" ]; then
    aws account close-account --account-id $account_id
  fi
done
```

## Final Verification

### Verify All Resources Deleted

```bash
#!/bin/bash
# Verify cleanup completion

echo "Verifying cleanup..."

ACCOUNTS=$(jq -r '.accounts[] | "\(.teamName):\(.accountId)"' deployment/config/accounts.json)

for account_info in $ACCOUNTS; do
  team_name=$(echo $account_info | cut -d: -f1)
  account_id=$(echo $account_info | cut -d: -f2)

  echo "Checking $team_name..."

  # Check for running instances
  instance_count=$(aws ec2 describe-instances \
    --region ap-south-1 \
    --filters "Name=instance-state-name,Values=running,stopped" \
    --query 'length(Reservations[*].Instances[*])' \
    --output text)

  echo "  EC2 Instances: $instance_count"

  # Check for S3 buckets
  bucket_count=$(aws s3 ls | wc -l)
  echo "  S3 Buckets: $bucket_count"

  # Check for RDS instances
  rds_count=$(aws rds describe-db-instances --query 'length(DBInstances)' --output text)
  echo "  RDS Instances: $rds_count"
done
```

### Generate Final Report

```bash
#!/bin/bash
# Generate final cleanup report

cat > cleanup-report.md << 'EOF'
# Hackathon 2025 - Cleanup Report

## Summary

- **Cleanup Date:** $(date)
- **Total Accounts:** 25
- **Status:** Complete

## Cost Summary

EOF

# Append cost data
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-31 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Team \
  >> cleanup-report.md

echo "✓ Cleanup report generated: cleanup-report.md"
```

## Best Practices

1. **Always run in dry-run mode first**
2. **Back up important data before deletion**
3. **Verify backups before proceeding**
4. **Delete resources in correct order** (dependencies)
5. **Document any retained resources**
6. **Archive all cost and compliance data**
7. **Keep CloudTrail logs for audit purposes**

## Troubleshooting

### Resources Won't Delete

**Problem:** Resources show as "in use" or fail to delete

**Solutions:**
- Check for dependencies (e.g., EIPs attached to instances)
- Delete in correct order
- Wait for async operations to complete
- Check for delete protection settings

### High Final Bills

**Problem:** Unexpected charges after cleanup

**Solutions:**
- Check for missed resources in other regions
- Verify S3 bucket cleanup
- Check for Elastic IPs not released
- Review snapshot retention
- Verify RDS automated backups are deleted

## Post-Cleanup Checklist

- [ ] All resources deleted
- [ ] Cost reports generated
- [ ] CloudTrail logs archived
- [ ] AWS Config data exported
- [ ] SSO assignments removed
- [ ] SCPs detached and deleted
- [ ] Final billing verified
- [ ] Documentation archived
- [ ] Lessons learned documented
- [ ] Thank you emails sent to participants

## Documentation Archive

Save these items for future reference:

1. Cost reports (per team and summary)
2. Resource inventories
3. CloudTrail logs (90-day minimum retention)
4. AWS Config compliance reports
5. Architecture diagrams
6. Lessons learned document
7. Participant feedback
8. Winning team projects (with permission)

## Contact

For cleanup assistance:
- Cloud Team: cloud-team@example.com
- AWS Support: [AWS Support Center](https://console.aws.amazon.com/support/)
