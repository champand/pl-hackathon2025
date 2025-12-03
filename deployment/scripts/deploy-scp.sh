#!/bin/bash

###############################################################################
# Deploy Service Control Policy (SCP) to Hackathon OU
# This script creates and attaches the hackathon guardrails SCP to the OU
###############################################################################

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCP_FILE="$ROOT_DIR/policies/scps/hackathon-guardrails-scp.json"

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

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy Service Control Policy to Hackathon OU

OPTIONS:
    -o, --ou-id <OU_ID>          Target Organizational Unit ID (required)
    -n, --policy-name <NAME>     SCP policy name (default: HackathonGuardrails)
    -d, --description <DESC>     Policy description
    -u, --update                 Update existing policy if it exists
    -h, --help                   Show this help message

EXAMPLE:
    $0 --ou-id ou-xxxx-xxxxxxxx --update

EOF
    exit 1
}

# Parse command line arguments
parse_args() {
    OU_ID=""
    POLICY_NAME="HackathonGuardrails"
    POLICY_DESC="Service Control Policy for AI Hackathon 2025 - Enforces security guardrails and cost controls"
    UPDATE_MODE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--ou-id)
                OU_ID="$2"
                shift 2
                ;;
            -n|--policy-name)
                POLICY_NAME="$2"
                shift 2
                ;;
            -d|--description)
                POLICY_DESC="$2"
                shift 2
                ;;
            -u|--update)
                UPDATE_MODE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    if [ -z "$OU_ID" ]; then
        log_error "OU ID is required"
        usage
    fi
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
    if ! aws organizations describe-organization &> /dev/null; then
        log_error "Not authenticated to AWS Organizations or insufficient permissions"
        exit 1
    fi

    # Check SCP file exists
    if [ ! -f "$SCP_FILE" ]; then
        log_error "SCP policy file not found: $SCP_FILE"
        exit 1
    fi

    # Validate JSON
    if ! jq empty "$SCP_FILE" 2>/dev/null; then
        log_error "Invalid JSON in SCP file: $SCP_FILE"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Check if policy exists
get_existing_policy_id() {
    local policy_name=$1

    local policy_id=$(aws organizations list-policies \
        --filter SERVICE_CONTROL_POLICY \
        --output json | \
        jq -r ".Policies[] | select(.Name == \"$policy_name\") | .Id")

    echo "$policy_id"
}

# Create new SCP
create_scp() {
    local policy_name=$1
    local policy_desc=$2
    local policy_content=$3

    log_info "Creating new SCP: $policy_name"

    local policy_id=$(aws organizations create-policy \
        --name "$policy_name" \
        --description "$policy_desc" \
        --type SERVICE_CONTROL_POLICY \
        --content "$policy_content" \
        --output json | jq -r '.Policy.PolicySummary.Id')

    if [ -z "$policy_id" ] || [ "$policy_id" == "null" ]; then
        log_error "Failed to create SCP"
        return 1
    fi

    log_info "✓ Created SCP: $policy_name (ID: $policy_id)"
    echo "$policy_id"
}

# Update existing SCP
update_scp() {
    local policy_id=$1
    local policy_name=$2
    local policy_desc=$3
    local policy_content=$4

    log_info "Updating existing SCP: $policy_name (ID: $policy_id)"

    aws organizations update-policy \
        --policy-id "$policy_id" \
        --name "$policy_name" \
        --description "$policy_desc" \
        --content "$policy_content" \
        --output json > /dev/null

    if [ $? -eq 0 ]; then
        log_info "✓ Updated SCP: $policy_name"
        return 0
    else
        log_error "Failed to update SCP"
        return 1
    fi
}

# Attach SCP to OU
attach_scp_to_ou() {
    local policy_id=$1
    local ou_id=$2

    log_info "Attaching SCP to OU: $ou_id"

    # Check if already attached
    local attached=$(aws organizations list-policies-for-target \
        --target-id "$ou_id" \
        --filter SERVICE_CONTROL_POLICY \
        --output json | \
        jq -r ".Policies[] | select(.Id == \"$policy_id\") | .Id")

    if [ -n "$attached" ]; then
        log_warn "SCP is already attached to OU: $ou_id"
        return 0
    fi

    aws organizations attach-policy \
        --policy-id "$policy_id" \
        --target-id "$ou_id"

    if [ $? -eq 0 ]; then
        log_info "✓ Attached SCP to OU: $ou_id"
        return 0
    else
        log_error "Failed to attach SCP to OU"
        return 1
    fi
}

# Verify OU exists
verify_ou() {
    local ou_id=$1

    log_info "Verifying OU exists: $ou_id"

    local ou_name=$(aws organizations describe-organizational-unit \
        --organizational-unit-id "$ou_id" \
        --output json 2>/dev/null | jq -r '.OrganizationalUnit.Name')

    if [ -z "$ou_name" ] || [ "$ou_name" == "null" ]; then
        log_error "OU not found: $ou_id"
        return 1
    fi

    log_info "✓ Found OU: $ou_name ($ou_id)"
    return 0
}

# List accounts in OU
list_ou_accounts() {
    local ou_id=$1

    log_info "Listing accounts in OU: $ou_id"

    local accounts=$(aws organizations list-accounts-for-parent \
        --parent-id "$ou_id" \
        --output json | jq -r '.Accounts[] | "\(.Id) - \(.Name)"')

    if [ -z "$accounts" ]; then
        log_warn "No accounts found in OU"
    else
        echo "$accounts" | while read -r account; do
            log_info "  Account: $account"
        done
    fi
}

# Main function
main() {
    log_info "Starting SCP Deployment"
    log_info "======================="

    parse_args "$@"
    check_prerequisites

    # Verify OU
    if ! verify_ou "$OU_ID"; then
        exit 1
    fi

    # List accounts in OU
    list_ou_accounts "$OU_ID"

    # Read policy content
    local policy_content=$(cat "$SCP_FILE" | jq -c .)

    # Check if policy exists
    local existing_policy_id=$(get_existing_policy_id "$POLICY_NAME")

    local policy_id=""

    if [ -n "$existing_policy_id" ]; then
        log_info "Found existing policy: $POLICY_NAME (ID: $existing_policy_id)"

        if [ "$UPDATE_MODE" = true ]; then
            # Update existing policy
            if update_scp "$existing_policy_id" "$POLICY_NAME" "$POLICY_DESC" "$policy_content"; then
                policy_id="$existing_policy_id"
            else
                exit 1
            fi
        else
            log_warn "Policy already exists. Use --update flag to update it."
            policy_id="$existing_policy_id"
        fi
    else
        # Create new policy
        policy_id=$(create_scp "$POLICY_NAME" "$POLICY_DESC" "$policy_content")
        if [ -z "$policy_id" ]; then
            exit 1
        fi
    fi

    # Attach policy to OU
    if ! attach_scp_to_ou "$policy_id" "$OU_ID"; then
        exit 1
    fi

    log_info "======================="
    log_info "✓ SCP Deployment Complete!"
    log_info "======================="
    log_info ""
    log_info "Policy ID: $policy_id"
    log_info "Policy Name: $POLICY_NAME"
    log_info "OU ID: $OU_ID"
    log_info ""
    log_info "The SCP is now active and will enforce guardrails on all accounts in the OU."
    log_info "Test the policy carefully before the hackathon starts."
}

# Run main function
main "$@"
