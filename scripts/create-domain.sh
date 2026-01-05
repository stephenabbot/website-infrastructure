#!/bin/bash
# scripts/create-domain.sh - Create new domain from template

set -euo pipefail

# Change to project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

# Check if required arguments are provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <domain-name>"
  echo ""
  echo "Examples:"
  echo "  $0 example.com"
  echo "  $0 my-site.org"
  echo ""
  echo "Domain will be converted to safe format (dots to hyphens) for directory structure"
  exit 1
fi

DOMAIN_NAME="$1"
DOMAIN_SAFE=$(echo "$DOMAIN_NAME" | tr '.' '-')

# Validate domain name format
if [[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\.[a-zA-Z]{2,}$ ]]; then
  echo "Error: Invalid domain name format: $DOMAIN_NAME"
  echo "Domain must be a valid format like example.com"
  exit 1
fi

TEMPLATE_DIR="${PROJECT_ROOT}/templates/new-domain"
TARGET_DIR="${PROJECT_ROOT}/projects/${DOMAIN_SAFE}"

# Check if domain already exists
if [ -d "$TARGET_DIR" ]; then
  echo "Error: Domain '${DOMAIN_NAME}' already exists at ${TARGET_DIR}"
  exit 1
fi

# Check if template exists
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Error: Template directory not found at ${TEMPLATE_DIR}"
  exit 1
fi

echo "Creating new domain: ${DOMAIN_NAME}"
echo "Safe Name: ${DOMAIN_SAFE}"
echo "Target Directory: ${TARGET_DIR}"
echo ""

# Copy template to new domain directory
cp -r "$TEMPLATE_DIR" "$TARGET_DIR"

# Process template files
cd "$TARGET_DIR/prd"

# Process domain template
if [ -f "domain.tf.template" ]; then
  sed "s/{{DOMAIN_NAME}}/$DOMAIN_NAME/g" "domain.tf.template" > "domain.tf"
  rm "domain.tf.template"
fi

echo "✓ Domain created successfully"
echo ""
echo "Next steps:"
echo "1. Review the domain configuration:"
echo "   ${TARGET_DIR}/prd/domain.tf"
echo ""
echo "2. Deploy all domains:"
echo "   ./scripts/deploy.sh"
echo ""
echo "3. The domain outputs will be available in infrastructure-outputs.json"
