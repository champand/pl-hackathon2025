#!/bin/bash

###############################################################################
# Hackathon Account Setup - Deployment Script
# This script deploys budget alerts and AWS Config to all hackathon accounts
###############################################################################

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLOUDFORMATION_DIR="$ROOT_DIR/cloudformation"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed"
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Load account configuration
load_account_config() {
    local config_file="$SCRIPT_DIR/../config/accounts.json"

    if [ ! -f "$config_file" ]; then
        log_error "Account configuration file not found: $config_file"
        exit 1
    fi

    echo "$config_file"
}

# Assume role in target account
assume_role() {
    local account_id=$1
    local role_name=${2:-OrganizationAccountAccessRole}

    log_info "Assuming role in account: $account_id"

    local role_arn="arn:aws:iam::${account_id}:role/${role_name}"

    local credentials=$(aws sts assume-role \
        --role-arn "$role_arn" \
        --role-session-name "hackathon-deployment-$(date +%s)" \
        --duration-seconds 3600 \
        --output json)

    export AWS_ACCESS_KEY_ID=$(echo "$credentials" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$credentials" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$credentials" | jq -r '.Credentials.SessionToken')
}

# Clear assumed role credentials
clear_assumed_role() {
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
}

# Deploy CloudFormation stack
deploy_stack() {
    local stack_name=$1
    local template_file=$2
    local parameters_file=$3
    local region=${4:-ap-south-1}

    log_info "Deploying stack: $stack_name"

    local deploy_cmd="aws cloudformation deploy \
        --template-file \"$template_file\" \
        --stack-name \"$stack_name\" \
        --region \"$region\" \
        --capabilities CAPABILITY_NAMED_IAM \
        --no-fail-on-empty-changeset"

    if [ -f "$parameters_file" ]; then
        deploy_cmd="$deploy_cmd --parameter-overrides file://$parameters_file"
    fi

    if eval "$deploy_cmd"; then
        log_info "Stack deployed successfully: $stack_name"
        return 0
    else
        log_error "Failed to deploy stack: $stack_name"
        return 1
    fi
}

# Wait for stack completion
wait_for_stack() {
    local stack_name=$1
    local region=${2:-ap-south-1}

    log_info "Waiting for stack to complete: $stack_name"

    aws cloudformation wait stack-create-complete \
        --stack-name "$stack_name" \
        --region "$region" 2>/dev/null || \
    aws cloudformation wait stack-update-complete \
        --stack-name "$stack_name" \
        --region "$region" 2>/dev/null

    log_info "Stack operation completed: $stack_name"
}

# Deploy budget stack
deploy_budget_stack() {
    local team_name=$1
    local account_id=$2
    local budget_limit=$3
    local cloud_team_email=$4
    local team_email=$5

    local stack_name="${team_name}-budget-alerts"
    local template_file="$CLOUDFORMATION_DIR/budget/hackathon-budget-alerts.yaml"

    # Create parameters file
    local params_file=$(mktemp)
    cat > "$params_file" << EOF
[
  {
    "ParameterKey": "TeamName",
    "ParameterValue": "$team_name"
  },
  {
    "ParameterKey": "MonthlyBudgetLimit",
    "ParameterValue": "$budget_limit"
  },
  {
    "ParameterKey": "EventBudgetLimit",
    "ParameterValue": "$((budget_limit * 4))"
  },
  {
    "ParameterKey": "CloudTeamEmail",
    "ParameterValue": "$cloud_team_email"
  },
  {
    "ParameterKey": "TeamEmail",
    "ParameterValue": "$team_email"
  }
]
EOF

    deploy_stack "$stack_name" "$template_file" "$params_file"
    local result=$?

    rm -f "$params_file"
    return $result
}

# Deploy Config stack
deploy_config_stack() {
    local team_name=$1
    local account_id=$2
    local cloud_team_email=$3

    local stack_name="${team_name}-config-monitoring"
    local template_file="$CLOUDFORMATION_DIR/config-monitoring/aws-config-setup.yaml"
    local bucket_name="${team_name}-config-${account_id}-ap-south-1"

    # Create parameters file
    local params_file=$(mktemp)
    cat > "$params_file" << EOF
[
  {
    "ParameterKey": "TeamName",
    "ParameterValue": "$team_name"
  },
  {
    "ParameterKey": "ConfigBucketName",
    "ParameterValue": "$bucket_name"
  },
  {
    "ParameterKey": "CloudTeamEmail",
    "ParameterValue": "$cloud_team_email"
  }
]
EOF

    deploy_stack "$stack_name" "$template_file" "$params_file"
    local result=$?

    rm -f "$params_file"
    return $result
}

# Enable Config recorder
enable_config_recorder() {
    local team_name=$1
    local region=${2:-ap-south-1}

    log_info "Enabling Config recorder for $team_name"

    aws configservice start-configuration-recorder \
        --configuration-recorder-name "${team_name}-config-recorder" \
        --region "$region" || true
}

# Process single account
process_account() {
    local team_name=$1
    local account_id=$2
    local budget_limit=$3
    local cloud_team_email=$4
    local team_email=$5
    local role_name=$6

    log_info "========================================="
    log_info "Processing account: $team_name ($account_id)"
    log_info "========================================="

    # Assume role
    assume_role "$account_id" "$role_name"

    # Deploy budget stack
    if deploy_budget_stack "$team_name" "$account_id" "$budget_limit" "$cloud_team_email" "$team_email"; then
        log_info "✓ Budget stack deployed for $team_name"
    else
        log_error "✗ Budget stack deployment failed for $team_name"
    fi

    # Deploy Config stack
    if deploy_config_stack "$team_name" "$account_id" "$cloud_team_email"; then
        log_info "✓ Config stack deployed for $team_name"
        enable_config_recorder "$team_name"
    else
        log_error "✗ Config stack deployment failed for $team_name"
    fi

    # Clear credentials
    clear_assumed_role

    log_info "Completed processing for $team_name"
    echo ""
}

# Main function
main() {
    log_info "Starting Hackathon Account Deployment"
    log_info "======================================"

    check_prerequisites

    # Configuration
    local config_file=$(load_account_config)
    local cloud_team_email=$(jq -r '.cloudTeamEmail' "$config_file")
    local role_name=$(jq -r '.assumeRoleName // "OrganizationAccountAccessRole"' "$config_file")

    # Get list of accounts
    local accounts=$(jq -c '.accounts[]' "$config_file")

    # Process each account
    while IFS= read -r account; do
        local team_name=$(echo "$account" | jq -r '.teamName')
        local account_id=$(echo "$account" | jq -r '.accountId')
        local budget_limit=$(echo "$account" | jq -r '.budgetLimit // 500')
        local team_email=$(echo "$account" | jq -r '.teamEmail')

        process_account "$team_name" "$account_id" "$budget_limit" "$cloud_team_email" "$team_email" "$role_name"

        # Add small delay between accounts
        sleep 2
    done <<< "$accounts"

    log_info "======================================"
    log_info "Deployment completed successfully!"
    log_info "======================================"
}

# Run main function
main "$@"
