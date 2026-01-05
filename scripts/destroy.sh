#!/bin/bash
# scripts/destroy.sh - Safely destroy domain infrastructure

set -euo pipefail

# Change to project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

# Disable AWS CLI pager
export AWS_PAGER=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}ℹ${NC} $1"; }

echo "🚨 DESTROY DOMAIN INFRASTRUCTURE 🚨"
echo ""
echo -e "${YELLOW}⚠${NC} This will PERMANENTLY DELETE all domain infrastructure!"
echo ""
echo -e "${YELLOW}⚠${NC} This includes:"
echo "  • S3 buckets and all content"
echo "  • CloudFront distributions"
echo "  • Route53 hosted zones and DNS records"
echo "  • ACM certificates"
echo "  • All SSM parameters"
echo ""
echo -e "${RED}✗${NC} THIS ACTION CANNOT BE UNDONE!"
echo ""

# Confirmation prompt
read -p "Type 'DESTROY' to confirm destruction: " confirmation
if [ "$confirmation" != "DESTROY" ]; then
    echo "Destruction cancelled."
    exit 0
fi

echo ""
print_status "Proceeding with destruction..."

# Verify prerequisites
echo ""
echo "Step 1: Verifying prerequisites..."
./scripts/verify-prerequisites.sh || exit 1

# Step 2: Check for project deployment role and assume if available
echo ""
echo "Step 2: Checking for project deployment role..."

# Extract project name from git remote URL
PROJECT_NAME=$(git remote get-url origin 2>/dev/null | sed -E 's|.*github\.com[:/][^/]+/([^/.]+)(\.git)?$|\1|' || echo "")

if [ -z "$PROJECT_NAME" ]; then
  echo -e "${YELLOW}⚠${NC} Could not determine project name from git remote"
  print_status "Using current credentials"
else
  print_status "Project name: $PROJECT_NAME"

  # Look up project-specific deployment role
  PROJECT_ROLE_ARN=$(aws ssm get-parameter --region us-east-1 --name "/deployment-roles/${PROJECT_NAME}/role-arn" --query Parameter.Value --output text 2>/dev/null || echo "")

  if [ -n "$PROJECT_ROLE_ARN" ]; then
    print_status "Project deployment role found: $PROJECT_ROLE_ARN"

    if TEMP_CREDS=$(aws sts assume-role --role-arn "$PROJECT_ROLE_ARN" --role-session-name "${PROJECT_NAME}-destroy-$(date +%s)" --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text 2>/dev/null); then
      export AWS_ACCESS_KEY_ID=$(echo "$TEMP_CREDS" | cut -f1)
      export AWS_SECRET_ACCESS_KEY=$(echo "$TEMP_CREDS" | cut -f2)
      export AWS_SESSION_TOKEN=$(echo "$TEMP_CREDS" | cut -f3)
      echo -e "${GREEN}✓${NC} Successfully assumed project deployment role"
    else
      echo -e "${YELLOW}⚠${NC} Failed to assume project role, using current credentials"
      print_status "This is normal for local development with admin credentials"
    fi
  else
    print_status "Project deployment role not found at /deployment-roles/${PROJECT_NAME}/role-arn"
    print_status "Using current credentials"
  fi
fi

# Step 3: Configure Terraform backend
echo ""
echo "Step 3: Configuring Terraform backend..."

STATE_BUCKET=$(aws ssm get-parameter --region us-east-1 --name "/terraform/foundation/s3-state-bucket" --query Parameter.Value --output text 2>/dev/null || echo "")
DYNAMODB_TABLE=$(aws ssm get-parameter --region us-east-1 --name "/terraform/foundation/dynamodb-lock-table" --query Parameter.Value --output text 2>/dev/null || echo "")

if [ -z "$STATE_BUCKET" ] || [ -z "$DYNAMODB_TABLE" ]; then
  echo -e "${RED}✗${NC} Foundation backend configuration not found"
  exit 1
fi

GITHUB_REPO=$(git remote get-url origin 2>/dev/null | sed 's/.*github\.com[:/]\([^/]*\/[^/.]*\).*/\1/' || echo "unknown/unknown")
BACKEND_KEY="static-website-infrastructure/$(echo "$GITHUB_REPO" | tr '/' '-')/terraform.tfstate"

print_status "Backend configuration:"
print_status "  Bucket: $STATE_BUCKET"
print_status "  Key: $BACKEND_KEY"

# Step 4: Initialize Terraform
echo ""
echo "Step 4: Initializing Terraform..."
tofu init -reconfigure \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="dynamodb_table=$DYNAMODB_TABLE" \
    -backend-config="key=$BACKEND_KEY" \
    -backend-config="region=us-east-1"

# Step 5: Plan destruction
echo ""
echo "Step 5: Planning destruction..."
tofu plan -destroy -out=destroy-plan

# Step 6: Apply destruction
echo ""
echo "Step 6: Applying destruction..."
tofu apply destroy-plan

# Step 7: Clean up SSM parameters
echo ""
echo "Step 7: Cleaning up SSM parameters..."

# Get list of domains that were deployed
if [ -f infrastructure-outputs.json ]; then
  jq -r '.deployed_domains.value | to_entries[] | .value.domain_name' infrastructure-outputs.json 2>/dev/null | while read -r domain_name; do
    if [ -n "$domain_name" ]; then
      print_status "Cleaning up SSM parameters for domain: $domain_name"
      
      # Delete all SSM parameters for this domain
      SSM_PARAMS=(
        "/static-website/infrastructure/$domain_name/bucket-name"
        "/static-website/infrastructure/$domain_name/bucket-arn"
        "/static-website/infrastructure/$domain_name/cloudfront-distribution-id"
        "/static-website/infrastructure/$domain_name/cloudfront-domain-name"
        "/static-website/infrastructure/$domain_name/certificate-arn"
        "/static-website/infrastructure/$domain_name/hosted-zone-id"
      )
      
      for param in "${SSM_PARAMS[@]}"; do
        aws ssm delete-parameter --region us-east-1 --name "$param" 2>/dev/null || true
      done
    fi
  done
fi

# Step 8: Clean up local files
echo ""
echo "Step 8: Cleaning up local files..."
rm -f tfplan destroy-plan infrastructure-outputs.json

echo ""
echo -e "${GREEN}✓${NC} DESTRUCTION COMPLETE"
echo ""
echo -e "${YELLOW}⚠${NC} Manual cleanup may be required for:"
echo -e "${YELLOW}⚠${NC}   • S3 bucket contents (if versioning was enabled)"
echo -e "${YELLOW}⚠${NC}   • Route53 hosted zone NS records in parent domain"
echo -e "${YELLOW}⚠${NC}   • Any external DNS configurations"
