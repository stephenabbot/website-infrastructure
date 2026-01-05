# Operations Guide

## Overview

This guide covers operational procedures for managing the website infrastructure project, including local development workflows and GitHub Actions CI/CD processes.

## Prerequisites Setup

Before using any scripts or workflows, ensure you have the required tools and configuration:

- AWS CLI configured with appropriate credentials
- OpenTofu installed (version 1.0+)
- GitHub CLI (`gh`) installed and authenticated
- `jq` for JSON processing
- Git repository access

For detailed setup instructions, see [prerequisites.md](prerequisites.md).

## Local Scripts

### Bootstrap Script

**Purpose**: Configure GitHub repository variables for OIDC authentication

```bash
./scripts/bootstrap.sh
```

**What it does**:
- Retrieves current AWS account ID
- Sets `AWS_ACCOUNT_ID` GitHub repository variable
- Handles existing variables gracefully
- Enables GitHub Actions OIDC authentication

**Requirements**: GitHub CLI authenticated with repository access

### Domain Creation Script

**Purpose**: Add new domain configuration to the project

```bash
./scripts/create-domain.sh <domain-name>
```

**What it does**:
- Creates domain directory structure in `projects/`
- Generates domain-specific configuration files
- Validates domain name format
- Prepares domain for infrastructure deployment

**Example**:
```bash
./scripts/create-domain.sh example.com
```

### Deployment Script

**Purpose**: Deploy all domain infrastructure using OpenTofu

```bash
./scripts/deploy.sh
```

**What it does**:
- Verifies prerequisites and AWS credentials
- Checks git repository state for cleanliness
- Retrieves backend configuration from SSM
- Initializes OpenTofu with remote state
- Plans and applies infrastructure changes
- Stores outputs in `infrastructure-outputs.json`
- Updates SSM parameters for each domain

**Prerequisites**:
- Clean git working directory
- Valid AWS credentials
- Foundation infrastructure deployed

### Resource Listing Script

**Purpose**: Display current infrastructure status and resources

```bash
./scripts/list-deployed-resources.sh
```

**What it does**:
- Shows deployed domains and their resources
- Displays CloudFront distribution IDs and domain names
- Lists S3 bucket names and ARNs
- Shows Route53 hosted zone IDs
- Provides SSL certificate ARNs

### Destroy Script

**Purpose**: Remove all infrastructure with confirmation prompts

```bash
./scripts/destroy.sh
```

**What it does**:
- Requires explicit confirmation
- Plans destruction of all resources
- Removes infrastructure in dependency order
- Cleans up SSM parameters
- Provides summary of destroyed resources

**Warning**: This is destructive and cannot be undone.

### Workflow Monitoring Script

**Purpose**: Monitor GitHub Actions workflows with configurable timeout

```bash
./scripts/watch-workflow.sh [timeout_seconds] [run_id]
```

**What it does**:
- Watches GitHub Actions workflow execution
- Provides real-time status updates
- Times out after specified duration (default: 10 seconds)
- Shows final workflow status and URL

**Examples**:
```bash
# Watch latest workflow for 10 seconds
./scripts/watch-workflow.sh 10

# Watch specific workflow run
./scripts/watch-workflow.sh 15 20698310188
```

### Prerequisites Verification Script

**Purpose**: Validate required tools and AWS configuration

```bash
./scripts/verify-prerequisites.sh
```

**What it does**:
- Checks for required command-line tools
- Validates AWS CLI configuration
- Verifies OpenTofu installation
- Tests GitHub CLI authentication
- Confirms foundation infrastructure availability

## GitHub Actions Workflows

### Deploy Infrastructure Workflow

**Trigger**: Manual dispatch with confirmation input
**File**: `.github/workflows/deploy.yml`

**Process**:
1. Validates confirmation input ("deploy")
2. Configures AWS credentials via OIDC
3. Retrieves backend configuration from SSM
4. Initializes OpenTofu with remote state
5. Plans and applies infrastructure changes
6. Generates and uploads outputs as artifacts

**OIDC Configuration**:
- Uses `vars.AWS_ACCOUNT_ID` GitHub variable
- Assumes role: `arn:aws:iam::ACCOUNT:role/gharole-website-infrastructure-prd`
- Session duration: 3600 seconds

**Backend State**:
- Bucket: Retrieved from `/terraform/foundation/s3-state-bucket` SSM parameter
- Key: `static-website-infrastructure/stephenabbot-website-infrastructure/terraform.tfstate`
- DynamoDB: Retrieved from `/terraform/foundation/dynamodb-lock-table` SSM parameter

### Destroy Infrastructure Workflow

**Trigger**: Manual dispatch with confirmation input
**File**: `.github/workflows/destroy.yml`

**Process**:
1. Validates confirmation input ("DESTROY")
2. Configures AWS credentials via OIDC
3. Retrieves backend configuration from SSM
4. Initializes OpenTofu with remote state
5. Plans and applies destruction
6. Cleans up SSM parameters

**Safety Features**:
- Requires "DESTROY" (all caps) confirmation
- Manual trigger only
- Comprehensive cleanup of SSM parameters

## OIDC Authentication

### Setup Process

1. Run bootstrap script to set GitHub variables:
   ```bash
   ./scripts/bootstrap.sh
   ```

2. Verify GitHub variable is set:
   ```bash
   gh variable list
   ```

### Role Configuration

The GitHub Actions workflows use OIDC to assume the deployment role:
- **Role Name**: `gharole-website-infrastructure-prd`
- **Trust Policy**: Allows GitHub Actions from `stephenabbot/website-infrastructure` repository
- **Permissions**: Managed by foundation IAM deployment roles project

### Debugging OIDC Issues

Both workflows include debug output showing:
- AWS Account ID from GitHub variable
- Repository name
- Expected role ARN
- GitHub token information

## State Management

### Backend Configuration

- **State Bucket**: Managed by foundation infrastructure
- **State Key**: `static-website-infrastructure/stephenabbot-website-infrastructure/terraform.tfstate`
- **Lock Table**: DynamoDB table managed by foundation infrastructure
- **Consistency**: Same backend used by local scripts and GitHub Actions

### State Operations

- **Initialization**: Automatic backend configuration retrieval from SSM
- **Locking**: DynamoDB-based state locking prevents concurrent modifications
- **Lock Cleanup**: Automatic stale lock removal before operations

## Monitoring and Troubleshooting

### Workflow Monitoring

Use the watch script for real-time monitoring:
```bash
./scripts/watch-workflow.sh 30 $(gh run list --limit 1 --json databaseId --template '{{(index . 0).databaseId}}')
```

### Common Issues

1. **OIDC Authentication Failures**
   - Verify `AWS_ACCOUNT_ID` GitHub variable is set
   - Check role trust policy allows repository
   - Confirm role exists and has correct permissions

2. **State Lock Issues**
   - Deploy script automatically clears stale locks
   - Manual cleanup: Check DynamoDB lock table

3. **Backend Configuration Errors**
   - Verify foundation infrastructure is deployed
   - Check SSM parameters exist and are accessible

4. **Resource Conflicts**
   - Ensure consistent backend state between local and CI/CD
   - Use same state key pattern across environments

### Log Analysis

GitHub Actions logs include:
- OIDC debug information
- Backend configuration details
- OpenTofu plan and apply output
- Resource creation/modification details

For detailed troubleshooting, see [troubleshooting.md](troubleshooting.md).

## Best Practices

### Development Workflow

1. Create feature branch for changes
2. Test locally with `./scripts/deploy.sh`
3. Commit and push changes
4. Trigger GitHub Actions deployment for validation
5. Merge to main branch

### Security Considerations

- Never commit AWS credentials to repository
- Use OIDC for GitHub Actions authentication
- Regularly rotate deployment role permissions
- Monitor CloudTrail for deployment activities

### Cost Management

- Monitor CloudFront and Route53 costs
- Review S3 storage and request charges
- Use cost allocation tags for tracking
- Set up billing alerts for unexpected charges

## Integration with Content Projects

### SSM Parameter Publishing

The infrastructure publishes resource identifiers to SSM Parameter Store:
- `/static-website/infrastructure/{domain}/bucket-name`
- `/static-website/infrastructure/{domain}/bucket-arn`
- `/static-website/infrastructure/{domain}/cloudfront-distribution-id`
- `/static-website/infrastructure/{domain}/cloudfront-domain-name`
- `/static-website/infrastructure/{domain}/certificate-arn`
- `/static-website/infrastructure/{domain}/hosted-zone-id`

### Content Deployment Integration

Content projects can retrieve infrastructure details:
```bash
BUCKET_NAME=$(aws ssm get-parameter --name "/static-website/infrastructure/example.com/bucket-name" --query Parameter.Value --output text)
DISTRIBUTION_ID=$(aws ssm get-parameter --name "/static-website/infrastructure/example.com/cloudfront-distribution-id" --query Parameter.Value --output text)
```

This enables loose coupling between infrastructure and content deployment processes.
