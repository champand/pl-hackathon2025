# AWS Resource Tagging Standards for Hackathon

## Overview

Proper resource tagging is essential for:
- Cost allocation and tracking
- Resource management
- Compliance monitoring
- Post-hackathon cleanup

## Required Tags

All resources **MUST** have the following tags:

| Tag Key | Description | Example Values | Required |
|---------|-------------|----------------|----------|
| `Team` | Team identifier | `team-01`, `team-02` | ✅ Yes |
| `Purpose` | Purpose of the resource | `ML-Training`, `WebAPI`, `Database` | ✅ Yes |
| `Environment` | Environment type | `Hackathon` | ✅ Yes |

## Recommended Tags

The following tags are recommended for better organization:

| Tag Key | Description | Example Values |
|---------|-------------|----------------|
| `Owner` | Team member responsible | `john.doe@example.com` |
| `CostCenter` | Cost tracking | `Hackathon2025` |
| `Project` | Project name | `ImageClassifier`, `ChatBot` |
| `CreatedBy` | Who created it | `alice@example.com` |
| `CreatedDate` | Creation date | `2025-12-10` |
| `ExpiryDate` | When to delete | `2025-12-31` |

## Tag Enforcement

### AWS Config Rules

AWS Config monitors required tags:

```yaml
ConfigRule: RequiredTags
- Tag: Team (Required)
- Tag: Purpose (Required)
```

Resources without required tags will be marked as **non-compliant**.

### CloudFormation Guard

CloudFormation templates are validated for tags:

```guard
rule required_tags_check when
    resourceType IN [
        'AWS::EC2::Instance',
        'AWS::RDS::DBInstance',
        'AWS::S3::Bucket'
    ] {
    Properties.Tags exists
    some Properties.Tags[*] {
        Key == 'Team'
        Value exists
    }
}
```

## Implementation Guide

### CloudFormation

```yaml
Resources:
  MyEC2Instance:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t3.medium
      ImageId: ami-12345678
      Tags:
        - Key: Team
          Value: team-01
        - Key: Purpose
          Value: ML-Training
        - Key: Environment
          Value: Hackathon
        - Key: Project
          Value: ImageClassifier
        - Key: Owner
          Value: john.doe@example.com
```

### AWS CLI

```bash
# Tag EC2 instance
aws ec2 create-tags \
  --resources i-1234567890abcdef0 \
  --tags \
    Key=Team,Value=team-01 \
    Key=Purpose,Value=WebAPI \
    Key=Environment,Value=Hackathon

# Tag S3 bucket
aws s3api put-bucket-tagging \
  --bucket my-hackathon-bucket \
  --tagging 'TagSet=[
    {Key=Team,Value=team-01},
    {Key=Purpose,Value=DataStorage},
    {Key=Environment,Value=Hackathon}
  ]'

# Tag RDS instance
aws rds add-tags-to-resource \
  --resource-name arn:aws:rds:ap-south-1:123456789012:db:mydb \
  --tags \
    Key=Team,Value=team-01 \
    Key=Purpose,Value=Database \
    Key=Environment,Value=Hackathon
```

### Terraform

```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.medium"

  tags = {
    Team        = "team-01"
    Purpose     = "WebServer"
    Environment = "Hackathon"
    Project     = "EcommercePlatform"
    Owner       = "alice@example.com"
  }
}
```

### AWS Console

1. Navigate to the resource
2. Click on **Tags** tab
3. Click **Manage tags**
4. Add required tags:
   - Key: `Team`, Value: `team-01`
   - Key: `Purpose`, Value: `ML-Training`
   - Key: `Environment`, Value: `Hackathon`
5. Click **Save**

## Tag Naming Conventions

### Team Tag Format

```
Format: team-XX
Examples:
  - team-01
  - team-02
  - team-25
```

### Purpose Tag Guidelines

Use descriptive names that indicate resource function:

**Good Examples:**
- `ML-Training`
- `WebAPI`
- `Database`
- `DataLake`
- `NotebookInstance`
- `ModelEndpoint`

**Bad Examples:**
- `test`
- `temp`
- `instance1`
- `stuff`

### Environment Tag

Always use: `Hackathon`

## Cost Allocation by Tags

### View Costs by Team

```bash
# Get cost by Team tag
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-31 \
  --granularity DAILY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Team
```

### Generate Cost Report

```bash
# Generate team cost report
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-31 \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Team \
  --filter file://filter.json

# filter.json
{
  "Tags": {
    "Key": "Environment",
    "Values": ["Hackathon"]
  }
}
```

## Bulk Tagging

### Tag Multiple Resources

```bash
#!/bin/bash
# Bulk tag all EC2 instances for team-01

TEAM="team-01"
REGION="ap-south-1"

# Get all instances for the team
INSTANCE_IDS=$(aws ec2 describe-instances \
  --region $REGION \
  --filters "Name=tag:Team,Values=$TEAM" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text)

# Tag each instance
for instance_id in $INSTANCE_IDS; do
  echo "Tagging instance: $instance_id"
  aws ec2 create-tags \
    --region $REGION \
    --resources $instance_id \
    --tags \
      Key=Environment,Value=Hackathon \
      Key=ExpiryDate,Value=2025-12-31
done
```

### Tag All Resources in Account

```python
#!/usr/bin/env python3
import boto3

def tag_all_resources(team_name):
    """Tag all taggable resources in the account"""

    # Initialize clients
    ec2 = boto3.client('ec2', region_name='ap-south-1')
    rds = boto3.client('rds', region_name='ap-south-1')
    s3 = boto3.client('s3')

    tags = [
        {'Key': 'Team', 'Value': team_name},
        {'Key': 'Environment', 'Value': 'Hackathon'},
        {'Key': 'ExpiryDate', 'Value': '2025-12-31'}
    ]

    # Tag EC2 instances
    instances = ec2.describe_instances()
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            print(f"Tagging EC2 instance: {instance_id}")
            ec2.create_tags(Resources=[instance_id], Tags=tags)

    # Tag RDS instances
    db_instances = rds.describe_db_instances()
    for db in db_instances['DBInstances']:
        db_arn = db['DBInstanceArn']
        print(f"Tagging RDS instance: {db_arn}")
        rds.add_tags_to_resource(ResourceName=db_arn, Tags=tags)

    # Tag S3 buckets
    buckets = s3.list_buckets()
    for bucket in buckets['Buckets']:
        bucket_name = bucket['Name']
        print(f"Tagging S3 bucket: {bucket_name}")
        s3.put_bucket_tagging(
            Bucket=bucket_name,
            Tagging={'TagSet': tags}
        )

if __name__ == '__main__':
    tag_all_resources('team-01')
```

## Tag Compliance Monitoring

### Check Untagged Resources

```bash
#!/bin/bash
# Find resources without required tags

REGION="ap-south-1"

echo "Checking EC2 instances without Team tag..."
aws ec2 describe-instances \
  --region $REGION \
  --filters "Name=tag-key,Values=Team" \
  --query 'Reservations[*].Instances[?!contains(Tags[?Key==`Team`].Value, `team-`)].[InstanceId, State.Name]' \
  --output table

echo "Checking untagged S3 buckets..."
aws s3api list-buckets --query 'Buckets[*].Name' --output text | \
  while read bucket; do
    tags=$(aws s3api get-bucket-tagging --bucket $bucket 2>/dev/null)
    if [ -z "$tags" ]; then
      echo "Untagged bucket: $bucket"
    fi
  done
```

### Generate Compliance Report

```bash
# Use AWS Config to get compliance report
aws configservice get-compliance-summary-by-config-rule \
  --config-rule-names team-01-required-tags \
  --query 'ComplianceSummary' \
  --output table
```

## Best Practices

### 1. Tag Early, Tag Often
- Tag resources immediately upon creation
- Use CloudFormation/Terraform to ensure tags are applied
- Don't wait until cleanup time

### 2. Use Consistent Naming
- Follow the team naming convention exactly
- Use PascalCase for multi-word purposes (e.g., `ML-Training`)
- Avoid spaces in tag values

### 3. Automate Tagging
- Use CloudFormation/Terraform tags
- Create tag policies at org level
- Use AWS Service Catalog for pre-tagged resources

### 4. Regular Audits
- Check for untagged resources daily
- Use AWS Config for automated monitoring
- Fix non-compliant resources immediately

### 5. Document Custom Tags
- Keep a registry of Purpose values used
- Share tagging conventions with team
- Update documentation as needed

## Post-Hackathon Cleanup

Tags facilitate cleanup:

```bash
# List all resources for a team
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Team,Values=team-01 \
  --region ap-south-1

# Delete all team resources (use with caution!)
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Team,Values=team-01 Key=Environment,Values=Hackathon \
  --query 'ResourceTagMappingList[*].ResourceARN' \
  --output text
```

## Example Tag Sets

### Machine Learning Project

```yaml
Tags:
  - Key: Team
    Value: team-01
  - Key: Purpose
    Value: ML-Training
  - Key: Environment
    Value: Hackathon
  - Key: Project
    Value: ImageClassification
  - Key: MLFramework
    Value: TensorFlow
  - Key: Owner
    Value: alice@example.com
```

### Web Application

```yaml
Tags:
  - Key: Team
    Value: team-02
  - Key: Purpose
    Value: WebAPI
  - Key: Environment
    Value: Hackathon
  - Key: Project
    Value: ChatbotAPI
  - Key: ApplicationTier
    Value: Backend
  - Key: Owner
    Value: bob@example.com
```

### Database

```yaml
Tags:
  - Key: Team
    Value: team-03
  - Key: Purpose
    Value: Database
  - Key: Environment
    Value: Hackathon
  - Key: Project
    Value: AnalyticsPlatform
  - Key: DatabaseEngine
    Value: PostgreSQL
  - Key: Owner
    Value: charlie@example.com
```

## Resources

- [AWS Tagging Best Practices](https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html)
- [AWS Cost Allocation Tags](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html)
- [AWS Config Managed Rules](https://docs.aws.amazon.com/config/latest/developerguide/managed-rules-by-aws-config.html)

## Questions?

Contact Cloud Team: cloud-team@example.com
