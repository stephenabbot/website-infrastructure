#!/bin/bash
# scripts/verify-prerequisites.sh - Verify deployment prerequisites

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}ℹ${NC} $1"; }

# Change to project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

print_status "Verifying prerequisites..."

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}✗${NC} Not in a git repository"
    exit 1
fi

# Check for required tools
REQUIRED_TOOLS=("tofu" "aws" "jq")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo -e "${RED}✗${NC} $tool is not installed or not in PATH"
        exit 1
    fi
done
echo -e "${GREEN}✓${NC} Required tools are available"

# Check git repository state
print_status "Checking git repository state..."

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${RED}✗${NC} Repository has uncommitted changes"
    git status --porcelain
    exit 1
fi

# Check for untracked files
if [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo -e "${RED}✗${NC} Repository has untracked files"
    git ls-files --others --exclude-standard
    exit 1
fi

# Check if local branch is up to date with remote
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if git ls-remote --exit-code origin "$BRANCH" > /dev/null 2>&1; then
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse "origin/$BRANCH")
    if [ "$LOCAL" != "$REMOTE" ]; then
        echo -e "${RED}✗${NC} Local branch is not up to date with remote"
        echo "  Run: git pull origin $BRANCH"
        exit 1
    fi
fi
echo -e "${GREEN}✓${NC} Git repository state is clean"

# Check AWS credentials
print_status "Checking AWS credentials..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}✗${NC} AWS credentials not configured or invalid"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓${NC} AWS credentials valid (Account: $ACCOUNT_ID)"

# Check foundation infrastructure
print_status "Checking foundation infrastructure..."
FOUNDATION_PARAMS=(
    "/terraform/foundation/s3-state-bucket"
    "/terraform/foundation/dynamodb-lock-table"
    "/terraform/foundation/oidc-provider"
)

for param in "${FOUNDATION_PARAMS[@]}"; do
    if ! aws ssm get-parameter --region us-east-1 --name "$param" > /dev/null 2>&1; then
        echo -e "${RED}✗${NC} Foundation parameter $param not found"
        echo "  Deploy terraform-aws-cfn-foundation first"
        exit 1
    fi
done
echo -e "${GREEN}✓${NC} Foundation infrastructure is available"

# Check deployment role
print_status "Checking deployment role..."

# Get project name from git remote
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
  PROJECT_NAME="${BASH_REMATCH[2]}"
else
  echo -e "${RED}✗${NC} Could not determine project name from git remote"
  exit 1
fi

ROLE_PARAM="/deployment-roles/${PROJECT_NAME}/role-arn"
if ! aws ssm get-parameter --region us-east-1 --name "$ROLE_PARAM" > /dev/null 2>&1; then
    echo -e "${RED}✗${NC} Deployment role parameter $ROLE_PARAM not found"
    echo "  Deploy terraform-aws-deployment-roles first"
    exit 1
fi
echo -e "${GREEN}✓${NC} Deployment role is available for project: $PROJECT_NAME"

# Check for at least one domain
print_status "Checking for configured domains..."
DOMAIN_COUNT=$(find projects -name "domain.tf" 2>/dev/null | wc -l | tr -d ' ')
if [ "$DOMAIN_COUNT" -eq 0 ]; then
    echo -e "${RED}✗${NC} No domains configured"
    echo "  Run: ./scripts/create-domain.sh <domain-name>"
    exit 1
fi
echo -e "${GREEN}✓${NC} Found $DOMAIN_COUNT configured domain(s)"

echo -e "${GREEN}✓${NC} All prerequisites verified successfully"
