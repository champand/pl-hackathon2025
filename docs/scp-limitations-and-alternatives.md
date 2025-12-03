# SCP Limitations and Alternative Enforcement Methods

## Overview

This document explains the limitations of Service Control Policies (SCPs) and how certain resource restrictions should be enforced using alternative methods.

## Issues Fixed in SCP

The following invalid condition keys were removed from the SCP as they are not supported by AWS:

### 1. VPC Peering Restrictions (Line 93)

**Invalid Condition Key**: `ec2:AccepterVpc`

**Issue**: This condition key does not exist in the EC2 service.

**Solution Applied**:
- **Removed** the invalid condition key
- **Changed** to block ALL VPC peering operations (both create and accept)
- This provides **stronger security** by preventing any VPC peering connections

**Statement**:
```json
{
  "Sid": "DenyVPCPeeringOperations",
  "Effect": "Deny",
  "Action": [
    "ec2:AcceptVpcPeeringConnection",
    "ec2:CreateVpcPeeringConnection"
  ],
  "Resource": "*"
}
```

### 2. MSK (Kafka) Broker Node Restrictions (Line 258)

**Invalid Condition Key**: `kafka:numberOfBrokerNodes`

**Issue**: AWS MSK does not expose broker node count as an SCP condition key.

**Solution Applied**:
- **Removed** this statement from SCP entirely

**Alternative Enforcement**: Use **AWS Config Rules**

```yaml
# Config Rule to check MSK cluster size
ConfigRule:
  Type: AWS::Config::ConfigRule
  Properties:
    ConfigRuleName: msk-broker-node-limit
    Source:
      Owner: CUSTOM_LAMBDA
      SourceIdentifier: arn:aws:lambda:region:account:function:check-msk-nodes
    MaximumExecutionFrequency: TwentyFour_Hours
```

**CloudFormation Guard Alternative**:
```guard
# In cfn-guard-rules.guard (already included)
rule msk_cluster_broker_limit when
    resourceType == 'AWS::MSK::Cluster' {

    Properties.NumberOfBrokerNodes <= 3

    <<
        Violation: MSK cluster cannot have more than 3 broker nodes.
    >>
}
```

### 3. OpenSearch Instance Type Restrictions (Line 272)

**Invalid Condition Key**: `es:InstanceType`

**Issue**: OpenSearch/Elasticsearch service does not expose instance type as an SCP condition key.

**Solution Applied**:
- **Removed** this statement from SCP entirely

**Alternative Enforcement**: Use **AWS Config Rules** or **CloudFormation Guard**

**AWS Config Rule**:
```yaml
ConfigRule:
  Type: AWS::Config::ConfigRule
  Properties:
    ConfigRuleName: opensearch-instance-type-check
    Source:
      Owner: CUSTOM_LAMBDA
      SourceIdentifier: arn:aws:lambda:region:account:function:check-opensearch-type
```

**CloudFormation Guard** (already included in repository):
```guard
# In cfn-guard-rules.guard
rule opensearch_instance_type_check when
    resourceType == 'AWS::OpenSearchService::Domain' {

    Properties.ClusterConfig.InstanceType IN [
        't3.small.search',
        't3.medium.search',
        't2.small.search',
        't2.medium.search',
        'm5.large.search',
        'm5.xlarge.search'
    ]

    <<
        Violation: OpenSearch instance type not allowed. Use t3.small, t3.medium, or small m5 instances.
    >>
}
```

### 4. EKS Node Group Instance Type Restrictions (Line 315)

**Invalid Condition Key**: `eks:InstanceTypes`

**Issue**: EKS does not expose node group instance types as an SCP condition key.

**Solution Applied**:
- **Removed** this statement from SCP entirely

**Alternative Enforcement**: Use **AWS Config Rules** or **CloudFormation Guard**

**CloudFormation Guard** (already included):
```guard
# In cfn-guard-rules.guard
rule eks_nodegroup_instance_type_check when
    resourceType == 'AWS::EKS::Nodegroup' {

    Properties.InstanceTypes[*] NOT IN [
        /.*\.8xlarge/,
        /.*\.12xlarge/,
        /.*\.16xlarge/,
        /.*\.24xlarge/,
        /.*\.32xlarge/,
        /p2\..*/,
        /p3\..*/,
        /p4\..*/,
        /p5\..*/,
        'g4dn.8xlarge',
        'g4dn.12xlarge',
        'g4dn.16xlarge'
    ]

    <<
        Violation: EKS node group instance type not allowed. Use smaller instances.
    >>
}
```

## Summary of Changes

| Service | Restriction | Previous Method | New Method |
|---------|-------------|-----------------|------------|
| VPC Peering | Cross-account peering | Invalid condition key | Block ALL peering operations |
| MSK (Kafka) | Broker node count | ❌ Invalid SCP condition | ✅ CloudFormation Guard + Config |
| OpenSearch | Instance types | ❌ Invalid SCP condition | ✅ CloudFormation Guard + Config |
| EKS | Node group instance types | ❌ Invalid SCP condition | ✅ CloudFormation Guard + Config |

## Updated SCP Coverage

The corrected SCP now properly enforces:

✅ **Region Restrictions** - ap-south-1 only (global services excluded)
✅ **Account Protection** - Cannot close or leave organization
✅ **Network Isolation** - No VPC peering, Transit Gateway, or RAM sharing
✅ **Security Services** - Cannot disable Config, CloudTrail, GuardDuty, Security Hub
✅ **IAM Identity Center** - Cannot modify SSO configuration
✅ **EC2 Instance Limits** - Maximum instance sizes enforced
✅ **GPU Instance Limits** - Expensive GPU instances blocked
✅ **RDS Instance Limits** - Maximum database instance sizes
✅ **SageMaker Limits** - Expensive ML instances blocked
✅ **ElastiCache Limits** - Allowed node types restricted
✅ **Budget Protection** - Cannot modify Cloud Team budgets
✅ **Log Protection** - Cannot delete Cloud Team log groups
✅ **Cross-Account Prevention** - No cross-account role assumption (except SSO)

## Multi-Layer Defense Strategy

For resources that cannot be controlled via SCP, we employ a **defense-in-depth** approach:

### Layer 1: Service Control Policy (SCP)
- Organization-level enforcement
- Blocks actions before they can be attempted
- **Best for**: Actions, regions, security services

### Layer 2: CloudFormation Guard Rules
- Validates CloudFormation templates before deployment
- Prevents creation of non-compliant resources via IaC
- **Best for**: Resource properties, configurations
- **Location**: `cloudformation/resource-limits/cfn-guard-rules.guard`

### Layer 3: AWS Config Rules
- Monitors deployed resources for compliance
- Alerts on non-compliant resources
- Can trigger auto-remediation
- **Best for**: Ongoing compliance monitoring
- **Location**: `cloudformation/config-monitoring/aws-config-setup.yaml`

### Layer 4: IAM Permission Boundaries (Optional)
- Account-level IAM restrictions
- Limits what IAM principals can do
- **Best for**: Additional IAM safeguards
- **Location**: `policies/iam-boundaries/hackathon-permission-boundary.json`

## Implementation Recommendations

### For MSK Clusters

1. **Use CloudFormation Guard** (Recommended)
   - Validates templates before deployment
   - Included in repository: `cfn-guard-rules.guard`

2. **Use AWS Config Rule** (Runtime Monitoring)
   - Create custom Lambda function
   - Monitor existing MSK clusters
   - Alert on violations

3. **Use Account Quotas** (Service Limit)
   - Request AWS Support to reduce MSK quotas
   - Limit max broker nodes to 3

### For OpenSearch Domains

1. **Use CloudFormation Guard** (Recommended)
   - Already included in repository
   - Validates instance types at deployment

2. **Use AWS Config Rule**
   - Custom Lambda to check domain configuration
   - Alert on non-compliant instance types

3. **IAM Permissions** (Additional Layer)
   - Limit who can create OpenSearch domains
   - Require approval workflow for large instances

### For EKS Node Groups

1. **Use CloudFormation Guard** (Recommended)
   - Already included in repository
   - Validates node group instance types

2. **Use AWS Config Rule**
   - Monitor node group configurations
   - Alert on large instance types

3. **EKS Add-ons**
   - Use Karpenter or Cluster Autoscaler with restrictions
   - Define allowed instance types in ConfigMaps

## Testing the Updated SCP

### Validate SCP Syntax

```bash
# Validate JSON syntax
jq empty policies/scps/hackathon-guardrails-scp.json

# Check for AWS-specific validation
aws organizations validate-policy-content \
  --policy-type SERVICE_CONTROL_POLICY \
  --content file://policies/scps/hackathon-guardrails-scp.json
```

### Test Enforcement

```bash
# Test 1: Try to create VPC peering (should be denied)
aws ec2 create-vpc-peering-connection \
  --vpc-id vpc-xxx \
  --peer-vpc-id vpc-yyy \
  --peer-owner-id 123456789012

# Expected: AccessDeniedException

# Test 2: Try to launch large instance (should be denied)
aws ec2 run-instances \
  --image-id ami-xxx \
  --instance-type m5.16xlarge \
  --region ap-south-1

# Expected: AccessDeniedException

# Test 3: Try to create resources outside ap-south-1 (should be denied)
aws ec2 run-instances \
  --image-id ami-xxx \
  --instance-type t3.micro \
  --region us-east-1

# Expected: AccessDeniedException
```

## CloudFormation Guard Testing

### Test MSK Restrictions

```bash
# Test invalid MSK cluster
cat > test-msk.yaml << 'EOF'
Resources:
  InvalidMSKCluster:
    Type: AWS::MSK::Cluster
    Properties:
      ClusterName: test-cluster
      NumberOfBrokerNodes: 6  # Should fail (> 3)
      BrokerNodeGroupInfo:
        InstanceType: kafka.m5.large
EOF

# Validate with Guard
cfn-guard validate \
  --data test-msk.yaml \
  --rules cloudformation/resource-limits/cfn-guard-rules.guard
```

### Test OpenSearch Restrictions

```bash
# Test invalid OpenSearch domain
cat > test-opensearch.yaml << 'EOF'
Resources:
  InvalidDomain:
    Type: AWS::OpenSearchService::Domain
    Properties:
      ClusterConfig:
        InstanceType: r5.large.search  # Should fail (not in allowed list)
EOF

# Validate
cfn-guard validate \
  --data test-opensearch.yaml \
  --rules cloudformation/resource-limits/cfn-guard-rules.guard
```

### Test EKS Restrictions

```bash
# Test invalid EKS node group
cat > test-eks.yaml << 'EOF'
Resources:
  InvalidNodeGroup:
    Type: AWS::EKS::Nodegroup
    Properties:
      ClusterName: my-cluster
      NodeRole: arn:aws:iam::123456789012:role/NodeRole
      InstanceTypes:
        - m5.16xlarge  # Should fail (too large)
EOF

# Validate
cfn-guard validate \
  --data test-eks.yaml \
  --rules cloudformation/resource-limits/cfn-guard-rules.guard
```

## Deployment Checklist

After updating the SCP:

- [ ] Validate JSON syntax
- [ ] Test SCP with AWS validation command
- [ ] Deploy updated SCP to Hackathon OU
- [ ] Verify CloudFormation Guard rules are in place
- [ ] Deploy AWS Config rules to all accounts
- [ ] Test enforcement with sample resources
- [ ] Document any exceptions or special cases
- [ ] Update team documentation
- [ ] Communicate changes to stakeholders

## Monitoring and Compliance

### Daily Monitoring

```bash
# Check Config compliance
aws configservice describe-compliance-by-config-rule \
  --compliance-types NON_COMPLIANT

# Check for SCP denials in CloudTrail
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ErrorCode,AttributeValue=AccessDenied \
  --max-results 50
```

### Weekly Reviews

1. Review Config compliance dashboard
2. Check for patterns in denied actions
3. Verify no workarounds are being used
4. Update policies if needed

## Frequently Asked Questions

### Q: Why can't SCPs control all resource properties?

**A**: SCPs operate at the API action level, not the resource property level. Some AWS services don't expose resource properties as condition keys in IAM policies.

### Q: Which method is most secure?

**A**: Use **all layers** together:
1. SCP blocks at organization level
2. CloudFormation Guard prevents IaC deployment
3. Config Rules monitor runtime compliance
4. Permission Boundaries add IAM restrictions

### Q: Can teams bypass these restrictions?

**A**: Not easily:
- SCPs cannot be circumvented within the account
- CloudFormation Guard blocks template deployment
- Config Rules detect manual creation
- Multiple layers make bypass very difficult

### Q: What if a team needs an exception?

**A**: Create a documented exception process:
1. Team submits request with justification
2. Cloud Team reviews and approves
3. Temporary exception granted via Config rule exemption
4. Resource tagged with exception approval ID
5. Exception expires after hackathon

## Additional Resources

- [AWS SCP Documentation](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)
- [AWS Config Rules](https://docs.aws.amazon.com/config/latest/developerguide/evaluate-config.html)
- [CloudFormation Guard](https://github.com/aws-cloudformation/cloudformation-guard)
- [IAM Condition Keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html)

## Change Log

| Date | Change | Reason |
|------|--------|--------|
| 2025-12-03 | Removed `ec2:AccepterVpc` condition | Invalid condition key |
| 2025-12-03 | Removed MSK broker node restriction | No SCP condition key available |
| 2025-12-03 | Removed OpenSearch instance type restriction | No SCP condition key available |
| 2025-12-03 | Removed EKS node group restriction | No SCP condition key available |
| 2025-12-03 | Enhanced VPC peering block to deny all operations | Stronger security posture |
| 2025-12-03 | Documented alternative enforcement via Config/Guard | Multi-layer defense |

---

**Last Updated**: December 3, 2025
**Maintained By**: Cloud Team
