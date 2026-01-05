# Prerequisites

## Required Tools

### AWS CLI
- **Version**: 2.0 or later
- **Installation**: [AWS CLI Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Configuration**: Must be configured with credentials that have deployment permissions

```bash
# Verify installation
aws --version

# Configure credentials
aws configure
```

### OpenTofu
- **Version**: 1.0 or later
- **Installation**: [OpenTofu Installation Guide](https://opentofu.org/docs/intro/install/)
- **Purpose**: Infrastructure as Code deployment

```bash
# Verify installation
tofu version
```

### GitHub CLI
- **Version**: Latest stable
- **Installation**: [GitHub CLI Installation](https://cli.github.com/)
- **Authentication**: Must be authenticated with repository access

```bash
# Install (macOS)
brew install gh

# Authenticate
gh auth login

# Verify access
gh repo view stephenabbot/website-infrastructure
```

### jq
- **Purpose**: JSON processing for configuration and outputs
- **Installation**: Available in most package managers

```bash
# Install (macOS)
brew install jq

# Install (Ubuntu/Debian)
sudo apt-get install jq
```

### Git
- **Version**: 2.0 or later
- **Purpose**: Version control and repository metadata extraction
- **Configuration**: Must be configured with user identity

```bash
# Configure Git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## AWS Prerequisites

### Foundation Infrastructure
This project requires foundation infrastructure to be deployed first:
- S3 state bucket for OpenTofu backend
- DynamoDB table for state locking
- OIDC provider for GitHub Actions authentication
- Deployment roles with appropriate permissions

**Repository**: [foundation-iam-deploy-roles](https://github.com/stephenabbot/foundation-iam-deploy-roles)

### AWS Permissions
The deployment requires permissions for:
- S3 bucket creation and management
- CloudFront distribution and function management
- Route53 hosted zone and record management
- ACM certificate creation and validation
- SSM parameter creation and management
- Route53 domain registration (if registering new domains)

### AWS Account Configuration
- **Account ID**: Must be consistent across local and CI/CD environments
- **Region**: Primary deployment region is `us-east-1`
- **Billing**: Ensure billing is configured for domain registration costs

## GitHub Configuration

### Repository Access
- **Permissions**: Admin or maintain access to repository
- **Variables**: Ability to set repository variables
- **Actions**: Ability to trigger workflow runs

### OIDC Setup
The bootstrap script will configure:
- `AWS_ACCOUNT_ID` repository variable
- GitHub Actions OIDC trust relationship with AWS

## Local Environment

### Directory Structure
Clone the repository and ensure clean working directory:
```bash
git clone https://github.com/stephenabbot/website-infrastructure.git
cd website-infrastructure
```

### Environment Variables
No environment variables are required. Configuration is retrieved from:
- AWS CLI configuration
- SSM Parameter Store
- Git repository metadata

### Network Access
Ensure network access to:
- AWS APIs (all regions)
- GitHub APIs
- OpenTofu registry
- Package managers for tool installation

## Verification

Run the prerequisites verification script:
```bash
./scripts/verify-prerequisites.sh
```

This script checks:
- Required tools are installed and accessible
- AWS CLI is configured with valid credentials
- GitHub CLI is authenticated
- Foundation infrastructure is available
- Git repository is in clean state

## Common Setup Issues

### AWS CLI Configuration
```bash
# Check current configuration
aws sts get-caller-identity

# Reconfigure if needed
aws configure
```

### GitHub CLI Authentication
```bash
# Check authentication status
gh auth status

# Re-authenticate if needed
gh auth login
```

### OpenTofu Installation
```bash
# Verify OpenTofu can access providers
tofu init -backend=false

# Check provider registry access
tofu providers
```

### Foundation Infrastructure
```bash
# Verify state bucket exists
aws ssm get-parameter --name "/terraform/foundation/s3-state-bucket"

# Verify lock table exists
aws ssm get-parameter --name "/terraform/foundation/dynamodb-lock-table"

# Verify OIDC provider exists
aws ssm get-parameter --name "/terraform/foundation/oidc-provider"
```

## Security Considerations

### Credential Management
- Never commit AWS credentials to repository
- Use IAM roles and temporary credentials when possible
- Regularly rotate access keys
- Enable MFA for AWS console access

### Repository Security
- Enable branch protection on main branch
- Require pull request reviews for changes
- Use signed commits when possible
- Monitor repository access logs

### Network Security
- Use HTTPS for all Git operations
- Verify SSL certificates for API endpoints
- Consider using VPN for sensitive operations
- Monitor network traffic for anomalies

## Troubleshooting

For common issues and solutions, see [troubleshooting.md](troubleshooting.md).

For operational procedures, see [operations.md](operations.md).
