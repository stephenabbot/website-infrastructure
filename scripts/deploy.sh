#!/bin/bash
# scripts/deploy.sh - Deploy ALL domain infrastructure using single Terraform configuration

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

echo "🚀 DEPLOYING ALL DOMAIN INFRASTRUCTURE 🚀"
echo ""
echo "This will deploy infrastructure for all configured domains using a single Terraform configuration"
echo ""

# Verify prerequisites
./scripts/verify-prerequisites.sh || exit 1

# Check for project deployment role and assume if available
echo ""

# Extract project name from git remote URL
PROJECT_NAME=$(git remote get-url origin 2>/dev/null | sed -E 's|.*github\.com[:/][^/]+/([^/.]+)(\.git)?$|\1|' || echo "")

if [ -z "$PROJECT_NAME" ]; then
  echo -e "${YELLOW}⚠${NC} Could not determine project name from git remote"
  echo "  Using current credentials"
else
  echo "  Project name: $PROJECT_NAME"

  # Look up project-specific deployment role
  PROJECT_ROLE_ARN=$(aws ssm get-parameter --region us-east-1 --name "/deployment-roles/${PROJECT_NAME}/role-arn" --query Parameter.Value --output text 2>/dev/null || echo "")

  if [ -n "$PROJECT_ROLE_ARN" ]; then
    echo -e "${GREEN}✓${NC} Project deployment role found: $PROJECT_ROLE_ARN"
    echo "  Attempting to assume role for deployment..."

    if TEMP_CREDS=$(aws sts assume-role --role-arn "$PROJECT_ROLE_ARN" --role-session-name "${PROJECT_NAME}-deploy-$(date +%s)" --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text 2>/dev/null); then
      export AWS_ACCESS_KEY_ID=$(echo "$TEMP_CREDS" | cut -f1)
      export AWS_SECRET_ACCESS_KEY=$(echo "$TEMP_CREDS" | cut -f2)
      export AWS_SESSION_TOKEN=$(echo "$TEMP_CREDS" | cut -f3)
      echo -e "${GREEN}✓${NC} Successfully assumed project deployment role"
    else
      echo -e "${YELLOW}⚠${NC} Failed to assume project role, using current credentials"
      echo "  This is normal for local development with admin credentials"
      echo "  For GitHub Actions, ensure OIDC is configured correctly"
    fi
  else
    echo -e "${BLUE}ℹ${NC} Project deployment role not found at /deployment-roles/${PROJECT_NAME}/role-arn"
    echo "  Using current credentials"
    echo "  To create a deployment role, run terraform-aws-deployment-roles"
  fi
fi

# Configure Terraform backend
echo ""

# Get backend configuration from foundation
STATE_BUCKET=$(aws ssm get-parameter --region us-east-1 --name "/terraform/foundation/s3-state-bucket" --query Parameter.Value --output text 2>/dev/null || echo "")
DYNAMODB_TABLE=$(aws ssm get-parameter --region us-east-1 --name "/terraform/foundation/dynamodb-lock-table" --query Parameter.Value --output text 2>/dev/null || echo "")

if [ -z "$STATE_BUCKET" ] || [ -z "$DYNAMODB_TABLE" ]; then
  echo -e "${RED}✗${NC} Foundation backend configuration not found"
  echo "  Deploy terraform-aws-cfn-foundation first"
  exit 1
fi

# Get GitHub repository info for state key
GITHUB_REPO=$(git remote get-url origin 2>/dev/null | sed 's/.*github\.com[:/]\([^/]*\/[^/.]*\).*/\1/' || echo "unknown/unknown")
BACKEND_KEY="static-website-infrastructure/$(echo "$GITHUB_REPO" | tr '/' '-')/terraform.tfstate"

echo -e "${GREEN}✓${NC} Backend configuration:"
echo "  Bucket: $STATE_BUCKET"
echo "  DynamoDB: $DYNAMODB_TABLE"
echo "  Key: $BACKEND_KEY"

# Initialize Terraform
echo ""

# Clear any stale DynamoDB locks before initialization
aws dynamodb scan --table-name "$DYNAMODB_TABLE" --filter-expression "contains(LockID, :key)" --expression-attribute-values "{\":key\":{\"S\":\"$BACKEND_KEY\"}}" --query 'Items[].LockID.S' --output text 2>/dev/null | tr '\t' '\n' | while read -r lock_id; do
  if [ -n "$lock_id" ]; then
    echo "Clearing stale lock: $lock_id"
    aws dynamodb delete-item --table-name "$DYNAMODB_TABLE" --key "{\"LockID\":{\"S\":\"$lock_id\"}}" 2>/dev/null || true
  fi
done

tofu init -reconfigure \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="dynamodb_table=$DYNAMODB_TABLE" \
    -backend-config="key=$BACKEND_KEY" \
    -backend-config="region=us-east-1"

# Plan deployment
echo ""
tofu plan -out=tfplan

# Apply deployment
echo ""
tofu apply tfplan

# Generate outputs and store in SSM
echo ""

# Generate outputs JSON (this will be gitignored)
tofu output -json > infrastructure-outputs.json

# Store individual domain outputs in SSM for consuming projects
if [ -f infrastructure-outputs.json ]; then
  # Parse deployed domains and store each in SSM
  jq -r '.deployed_domains.value | to_entries[] | "\(.key) \(.value.domain_name) \(.value.bucket_name) \(.value.bucket_arn) \(.value.cloudfront_distribution_id) \(.value.cloudfront_domain_name) \(.value.certificate_arn) \(.value.hosted_zone_id)"' infrastructure-outputs.json | while read -r key domain_name bucket_name bucket_arn distribution_id distribution_domain cert_arn zone_id; do
    echo "Storing SSM parameters for domain: $domain_name"
    
    aws ssm put-parameter --region us-east-1 --name "/static-website/infrastructure/$domain_name/bucket-name" --value "$bucket_name" --type String --overwrite > /dev/null
    aws ssm put-parameter --region us-east-1 --name "/static-website/infrastructure/$domain_name/bucket-arn" --value "$bucket_arn" --type String --overwrite > /dev/null
    aws ssm put-parameter --region us-east-1 --name "/static-website/infrastructure/$domain_name/cloudfront-distribution-id" --value "$distribution_id" --type String --overwrite > /dev/null
    aws ssm put-parameter --region us-east-1 --name "/static-website/infrastructure/$domain_name/cloudfront-domain-name" --value "$distribution_domain" --type String --overwrite > /dev/null
    aws ssm put-parameter --region us-east-1 --name "/static-website/infrastructure/$domain_name/certificate-arn" --value "$cert_arn" --type String --overwrite > /dev/null
    aws ssm put-parameter --region us-east-1 --name "/static-website/infrastructure/$domain_name/hosted-zone-id" --value "$zone_id" --type String --overwrite > /dev/null
  done
fi

echo ""
echo -e "${GREEN}✅ DEPLOYMENT COMPLETE${NC}"
echo ""
echo "📋 Summary:"
echo "  • All domain infrastructure deployed successfully"
echo "  • Outputs stored in infrastructure-outputs.json (gitignored)"
echo "  • Individual domain parameters stored in SSM Parameter Store"
echo ""
echo "🔍 Next steps:"
echo "  • Review outputs: cat infrastructure-outputs.json | jq"
echo "  • List resources: ./scripts/list-deployed-resources.sh"
echo "  • Deploy content to domains using their respective content projects"
