# AI Hackathon 2025 - AWS Multi-Account Infrastructure

Enterprise-grade AWS multi-account architecture and automation for secure, isolated hackathon environments with comprehensive cost controls and security guardrails.

## 🎯 Overview

This repository contains production-ready Infrastructure as Code (IaC) and automation tools to provision and manage 25 isolated AWS accounts for an AI Hackathon, ensuring:

- ✅ **Complete isolation** between teams
- ✅ **Security guardrails** to protect production workloads
- ✅ **Cost controls** with automated budget alerts
- ✅ **Compliance enforcement** via AWS Config
- ✅ **Administrator access** for teams within their own accounts
- ✅ **Zero cross-account interference**

## 📋 Table of Contents

- [Architecture](#architecture)
- [Features](#features)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Components](#components)
- [Deployment](#deployment)
- [Security Guardrails](#security-guardrails)
- [Cost Management](#cost-management)
- [Monitoring & Compliance](#monitoring--compliance)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   AWS Organizations (Root)                       │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              IAM Identity Center (SSO)                    │  │
│  │  - AD Group: hackathon-team-01 → team-25                │  │
│  │  - Permission Set: HackathonAdministrator                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   Hackathon OU                            │  │
│  │                                                            │  │
│  │  SCP: HackathonGuardrails (Attached to OU)               │  │
│  │  - Region restrictions (ap-south-1 only)                 │  │
│  │  - Resource size limits                                   │  │
│  │  - Cost controls                                          │  │
│  │  - Security service protection                            │  │
│  │                                                            │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  Team-01 Account (123456789012)                    │  │  │
│  │  │  - Budget: $500/month                               │  │  │
│  │  │  - AWS Config: Enabled                              │  │  │
│  │  │  - CloudTrail: Enabled                              │  │  │
│  │  │  - GuardDuty: Enabled                               │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  │                                                            │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  Team-02 Account (123456789013)                    │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  │                                                            │  │
│  │  ... (Team 03 - 24)                                       │  │
│  │                                                            │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  Team-25 Account (123456789036)                    │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Account-Level Architecture

Each team account includes:

```
Team Account
├── IAM Identity Center Access (AdministratorAccess)
├── Service Control Policy (Inherited from OU)
├── AWS Budgets
│   ├── Monthly Budget ($500)
│   ├── Event Budget ($2000)
│   ├── EC2 Usage Budget
│   └── SageMaker Usage Budget
├── AWS Config
│   ├── Configuration Recorder
│   ├── Delivery Channel
│   └── Compliance Rules (15+ rules)
├── CloudWatch Alarms
│   └── Estimated Charges Alarm
├── SNS Topics
│   ├── Budget Alerts
│   └── Config Compliance Notifications
└── Optional: IAM Permission Boundary
```

## ✨ Features

### Security Features

- **Service Control Policies (SCPs)** - Organization-level guardrails
  - Region restriction (ap-south-1 only, global services excluded)
  - Account deletion prevention
  - VPC peering restrictions
  - Security service protection (Config, CloudTrail, GuardDuty)
  - Cross-account access prevention

- **IAM Permission Boundaries** - Account-level controls
  - Prevent privilege escalation
  - Enforce tagging requirements
  - Additional resource restrictions

- **AWS Config Rules** - Compliance monitoring
  - Instance type validation
  - Encryption enforcement
  - Public access prevention
  - Tagging compliance

### Cost Management Features

- **Multi-tier Budgets**
  - Monthly budget ($500 default)
  - Event-wide budget ($2000 default)
  - Per-service budgets (EC2, SageMaker)

- **Automated Alerts**
  - 50%, 75%, 90% actual spend thresholds
  - 100% forecasted spend threshold
  - CloudWatch billing alarms
  - SNS email notifications to teams and cloud team

### Resource Limit Features

- **EC2 Instance Restrictions**
  - Maximum size: 4xlarge
  - GPU instances: Limited to smaller types
  - Expensive instance families blocked

- **Database Restrictions**
  - RDS: Maximum 4xlarge instances
  - ElastiCache: T2/T3/T4g small-medium only
  - OpenSearch: T2/T3 small-medium only

- **AI/ML Restrictions**
  - SageMaker: Limited large instances
  - Controlled GPU access for training
  - Reasonable endpoint sizes

### Access Management Features

- **IAM Identity Center (SSO)**
  - AD group integration
  - Automatic account assignment
  - 8-hour session duration
  - MFA support

- **Automation Scripts**
  - Bulk account provisioning
  - Permission set creation
  - Account assignment automation

## 📁 Repository Structure

```
pl-hackathon2025/
├── README.md                          # This file
├── policies/
│   ├── scps/
│   │   └── hackathon-guardrails-scp.json    # Service Control Policy
│   └── iam-boundaries/
│       └── hackathon-permission-boundary.json  # IAM Permission Boundary
├── cloudformation/
│   ├── budget/
│   │   └── hackathon-budget-alerts.yaml      # Budget monitoring template
│   ├── config-monitoring/
│   │   └── aws-config-setup.yaml             # AWS Config template
│   └── resource-limits/
│       ├── cfn-guard-rules.guard             # CloudFormation Guard rules
│       └── cfn-hooks-config.yaml             # Hooks configuration
├── deployment/
│   ├── scripts/
│   │   ├── deploy-to-all-accounts.sh         # Deploy to all 25 accounts
│   │   ├── deploy-scp.sh                     # Deploy SCP to OU
│   │   └── setup-sso.py                      # IAM Identity Center automation
│   ├── config/
│   │   └── accounts.json.example             # Account configuration template
│   └── guides/
│       └── DEPLOYMENT_GUIDE.md               # Detailed deployment guide
├── docs/
│   └── iam-identity-center-setup.md          # SSO configuration guide
└── examples/
    └── test-templates/                       # Test CloudFormation templates
```

## 🚀 Quick Start

### Prerequisites

```bash
# Install required tools
aws --version        # AWS CLI v2+
jq --version         # JSON processor
python3 --version    # Python 3.8+
```

### 1. Clone Repository

```bash
git clone https://github.com/your-org/pl-hackathon2025.git
cd pl-hackathon2025
```

### 2. Configure Accounts

```bash
# Copy and edit configuration
cp deployment/config/accounts.json.example deployment/config/accounts.json
vim deployment/config/accounts.json
```

### 3. Deploy SCP

```bash
cd deployment/scripts
chmod +x deploy-scp.sh
./deploy-scp.sh --ou-id ou-xxxx-xxxxxxxx
```

### 4. Configure IAM Identity Center

```bash
# Follow the detailed guide
cat ../../docs/iam-identity-center-setup.md
```

### 5. Deploy to All Accounts

```bash
chmod +x deploy-to-all-accounts.sh
./deploy-to-all-accounts.sh
```

For detailed deployment instructions, see [Deployment Guide](deployment/guides/DEPLOYMENT_GUIDE.md).

## 🔧 Components

### 1. Service Control Policy (SCP)

**Location:** `policies/scps/hackathon-guardrails-scp.json`

**Purpose:** Enforces organization-wide guardrails at the OU level

**Key Restrictions:**
- ✅ Region enforcement (ap-south-1 only)
- ✅ Prevent account closure/leaving organization
- ✅ Block VPC peering and Transit Gateway
- ✅ Prevent AWS RAM sharing
- ✅ Protect security services (Config, CloudTrail, GuardDuty)
- ✅ Block extremely large EC2/RDS/SageMaker instances
- ✅ Limit GPU instance types
- ✅ Prevent cross-account role assumption (except SSO)

**Deployment:**
```bash
./deployment/scripts/deploy-scp.sh --ou-id ou-xxxx-xxxxxxxx
```

### 2. IAM Permission Boundary

**Location:** `policies/iam-boundaries/hackathon-permission-boundary.json`

**Purpose:** Optional additional safeguards at account level

**Features:**
- Region enforcement
- Prevent security service tampering
- Enforce permission boundary on new IAM users/roles
- Protect Cloud Team managed resources

**Deployment:**
```bash
aws iam create-policy \
  --policy-name HackathonPermissionBoundary \
  --policy-document file://policies/iam-boundaries/hackathon-permission-boundary.json
```

### 3. Budget Alerts

**Location:** `cloudformation/budget/hackathon-budget-alerts.yaml`

**Purpose:** Automated cost monitoring and alerting

**Creates:**
- Monthly budget with 4 alert thresholds
- Event-wide budget
- EC2 usage budget
- SageMaker usage budget
- SNS topics and email subscriptions
- CloudWatch billing alarms

**Parameters:**
- `TeamName` - Team identifier
- `MonthlyBudgetLimit` - Monthly spend limit
- `CloudTeamEmail` - Cloud team notification email
- `TeamEmail` - Team notification email

### 4. AWS Config Setup

**Location:** `cloudformation/config-monitoring/aws-config-setup.yaml`

**Purpose:** Compliance monitoring and resource tracking

**Creates:**
- Configuration recorder
- S3 bucket for Config data
- 10+ compliance rules
- SNS notifications for non-compliance
- EventBridge rules for compliance changes

**Config Rules:**
- EC2 instance type validation
- RDS encryption enforcement
- S3 encryption and public access prevention
- IAM password policy
- Root account MFA
- Required tagging

### 5. CloudFormation Guard Rules

**Location:** `cloudformation/resource-limits/cfn-guard-rules.guard`

**Purpose:** Proactive resource limit enforcement

**Enforces:**
- EC2 instance type restrictions
- RDS instance class limits
- OpenSearch instance size limits
- ElastiCache node type restrictions
- SageMaker instance limits
- EKS node group restrictions
- Required resource tagging
- Encryption requirements

## 📦 Deployment

### Deployment Order

1. **Create OU Structure** (Manual)
2. **Deploy SCP** (Script: `deploy-scp.sh`)
3. **Configure IAM Identity Center** (Guide + Scripts)
4. **Deploy Budgets** (Script: `deploy-to-all-accounts.sh`)
5. **Deploy AWS Config** (Script: `deploy-to-all-accounts.sh`)
6. **Validate** (Manual testing)

### Automated Deployment

```bash
# Deploy everything to all accounts
cd deployment/scripts
./deploy-to-all-accounts.sh
```

This script:
- Assumes role in each account
- Deploys budget monitoring
- Deploys AWS Config
- Enables Config recorder
- Validates deployments

### Manual Deployment (Single Account)

```bash
# Deploy budget alerts
aws cloudformation deploy \
  --template-file cloudformation/budget/hackathon-budget-alerts.yaml \
  --stack-name team-01-budget-alerts \
  --parameter-overrides \
    TeamName=team-01 \
    MonthlyBudgetLimit=500 \
    CloudTeamEmail=cloud-team@example.com \
    TeamEmail=team-01@example.com \
  --capabilities CAPABILITY_NAMED_IAM

# Deploy AWS Config
aws cloudformation deploy \
  --template-file cloudformation/config-monitoring/aws-config-setup.yaml \
  --stack-name team-01-config-monitoring \
  --parameter-overrides \
    TeamName=team-01 \
    ConfigBucketName=team-01-config-123456789012-ap-south-1 \
    CloudTeamEmail=cloud-team@example.com \
  --capabilities CAPABILITY_NAMED_IAM
```

## 🔒 Security Guardrails

### Defense in Depth

Multiple layers of security controls:

```
Layer 1: Service Control Policy (OU Level)
    ↓ Inherited by all accounts
Layer 2: IAM Permission Boundary (Account Level)
    ↓ Applied to IAM users/roles
Layer 3: AWS Config Rules (Resource Level)
    ↓ Monitors compliance
Layer 4: CloudFormation Guard (Deployment Level)
    ↓ Prevents non-compliant resource creation
```

### Preventing Common Issues

| Threat | Mitigation |
|--------|------------|
| Account deletion | SCP blocks `organizations:CloseAccount` |
| Cross-account access | SCP blocks `sts:AssumeRole` (except SSO) |
| Production interference | Complete account isolation via OU |
| Cost explosion | Budgets, alerts, resource size limits |
| Security service tampering | SCP blocks deletion/modification |
| Wrong region usage | SCP enforces ap-south-1 |
| Large instance creation | SCP + Config + Guard rules |
| Data exfiltration | VPC peering/RAM sharing blocked |

## 💰 Cost Management

### Budget Structure

Each account has 4 budgets:

1. **Monthly Budget** ($500 default)
   - Alerts at 50%, 75%, 90%, 100% (forecasted)
   - Resets monthly

2. **Event-Wide Budget** ($2000 default)
   - Total spend across hackathon period
   - Alerts at 80%, 100%

3. **EC2 Usage Budget** ($1000 max)
   - Tracks EC2 costs specifically
   - Alert at 80%

4. **SageMaker Usage Budget** ($500 max)
   - Tracks AI/ML costs
   - Alert at 80%

### Alert Recipients

- **Cloud Team**: All alerts
- **Hackathon Team**: All alerts for their account

### Cost Optimization Tips

1. **Use spot instances** for non-critical workloads
2. **Stop resources** when not in use
3. **Use smaller instance types** where possible
4. **Leverage AWS Free Tier** resources
5. **Set up auto-scaling** with conservative limits

### Monitoring Costs

```bash
# View current spend
aws ce get-cost-and-usage \
  --time-period Start=2025-12-01,End=2025-12-31 \
  --granularity MONTHLY \
  --metrics UnblendedCost

# Check budget status
aws budgets describe-budget \
  --account-id 123456789012 \
  --budget-name team-01-monthly-budget
```

## 📊 Monitoring & Compliance

### AWS Config Dashboard

Monitor compliance across all accounts:

```bash
# Check compliance summary
aws configservice describe-compliance-by-config-rule

# View specific rule compliance
aws configservice describe-compliance-by-config-rule \
  --config-rule-names team-01-ec2-instance-type-check
```

### CloudWatch Dashboards

Create unified dashboard:

```bash
# Create cross-account dashboard
aws cloudwatch put-dashboard \
  --dashboard-name HackathonOverview \
  --dashboard-body file://dashboards/hackathon-dashboard.json
```

### Compliance Reports

Generate compliance reports:

```bash
# Get Config snapshot
aws configservice deliver-config-snapshot \
  --delivery-channel-name team-01-delivery-channel

# List non-compliant resources
aws configservice get-compliance-details-by-config-rule \
  --config-rule-name team-01-ec2-instance-type-check \
  --compliance-types NON_COMPLIANT
```

## 🎯 Best Practices

### 1. Testing

- Test all policies in non-production accounts first
- Validate SCPs don't block legitimate operations
- Test budget alert delivery
- Verify Config rules trigger correctly

### 2. Documentation

- Maintain updated team access guide
- Document any policy exceptions
- Keep runbooks for common issues
- Track all configuration changes

### 3. Communication

- Send welcome emails with access instructions
- Provide clear escalation paths
- Set up Slack/Teams channel for support
- Schedule office hours for questions

### 4. Monitoring

- Review budget alerts daily during hackathon
- Monitor Config compliance dashboard
- Check CloudTrail for unusual activity
- Set up aggregated CloudWatch dashboard

### 5. Cleanup

- Document cleanup procedures
- Schedule post-hackathon deprovisioning
- Archive important logs/data
- Generate cost reports for each team

## 🐛 Troubleshooting

### Common Issues

#### SCP Blocking Legitimate Actions

**Problem:** Teams report they can't perform needed actions

**Solution:**
1. Check CloudTrail for denied API calls
2. Review SCP policy for overly restrictive conditions
3. Update SCP if needed (use `--update` flag)
4. Allow 5-10 minutes for propagation

#### Budget Alerts Not Received

**Problem:** No email notifications for budget alerts

**Solution:**
1. Check SNS subscription status (must be confirmed)
2. Check spam folders
3. Test SNS topic manually
4. Verify budget was created successfully

#### Config Rules Showing Non-Compliant

**Problem:** Resources flagged as non-compliant

**Solution:**
1. Review specific Config rule requirements
2. Check if resources are legitimately non-compliant
3. Remediate or update Config rule parameters
4. Resources created before Config may need re-evaluation

#### SSO Access Not Working

**Problem:** Users can't access accounts via SSO

**Solution:**
1. Verify AD group membership
2. Check account assignment exists
3. Ensure permission set is provisioned
4. Verify MFA is configured (if required)

### Getting Help

1. Check [Deployment Guide](deployment/guides/DEPLOYMENT_GUIDE.md)
2. Review [IAM Identity Center Setup](docs/iam-identity-center-setup.md)
3. Check AWS documentation
4. Contact Cloud Team: cloud-team@example.com

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

[Specify your license here]

## 🙏 Acknowledgments

- AWS Solutions Architects
- Cloud Team
- Hackathon Organizing Committee

## 📞 Support

- **Cloud Team Email:** cloud-team@example.com
- **Documentation:** [deployment/guides/](deployment/guides/)
- **Issues:** [GitHub Issues](https://github.com/your-org/pl-hackathon2025/issues)

---

**Built with ❤️ for AI Hackathon 2025**
