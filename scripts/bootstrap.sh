#!/bin/bash
# scripts/bootstrap.sh - Bootstrap GitHub repository variables for deployment workflows

set -euo pipefail

# Change to project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "🔧 BOOTSTRAPPING GITHUB REPOSITORY VARIABLES 🔧"
echo ""

# Check if gh CLI is available
if ! command -v gh &>/dev/null; then
  echo "❌ GitHub CLI (gh) not found"
  echo "  Install: https://cli.github.com/"
  exit 1
fi

# Check if authenticated with GitHub
if ! gh auth status &>/dev/null; then
  echo "❌ Not authenticated with GitHub CLI"
  echo "  Run: gh auth login"
  exit 1
fi

# Get AWS account ID
echo "Getting AWS account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [ -z "$ACCOUNT_ID" ]; then
  echo "❌ Failed to get AWS account ID"
  echo "  Ensure AWS credentials are configured"
  exit 1
fi

echo "✓ AWS Account ID: $ACCOUNT_ID"

# Check if AWS_ACCOUNT_ID variable already exists
echo ""
echo "Checking GitHub repository variables..."

if gh variable list | grep -q "AWS_ACCOUNT_ID"; then
  EXISTING_VALUE=$(gh variable list | grep "AWS_ACCOUNT_ID" | awk '{print $2}')
  if [ "$EXISTING_VALUE" = "$ACCOUNT_ID" ]; then
    echo -e "${GREEN}✓${NC} AWS_ACCOUNT_ID already set correctly: $ACCOUNT_ID"
  else
    echo -e "${YELLOW}⚠${NC} AWS_ACCOUNT_ID exists but differs: $EXISTING_VALUE vs $ACCOUNT_ID"
    echo "  Updating to current account ID..."
    gh variable set AWS_ACCOUNT_ID --body "$ACCOUNT_ID"
    echo -e "${GREEN}✓${NC} Updated AWS_ACCOUNT_ID: $ACCOUNT_ID"
  fi
else
  echo "Setting AWS_ACCOUNT_ID GitHub variable..."
  gh variable set AWS_ACCOUNT_ID --body "$ACCOUNT_ID"
  echo -e "${GREEN}✓${NC} Set AWS_ACCOUNT_ID: $ACCOUNT_ID"
fi

echo ""
echo "🔧 BOOTSTRAP COMPLETE 🔧"
echo ""
echo "GitHub Actions workflows can now use \${{ vars.AWS_ACCOUNT_ID }} to construct role ARNs"
