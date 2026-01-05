# Content Deployment Guide

## Overview

After infrastructure deployment, content projects can deploy websites using the published SSM parameters. This guide explains the integration pattern and provides a reference implementation.

## Integration Pattern

### SSM Parameter Discovery

The infrastructure project publishes resource identifiers to SSM Parameter Store:

```
/static-website/infrastructure/{domain}/bucket-name
/static-website/infrastructure/{domain}/bucket-arn
/static-website/infrastructure/{domain}/cloudfront-distribution-id
/static-website/infrastructure/{domain}/cloudfront-domain-name
/static-website/infrastructure/{domain}/certificate-arn
/static-website/infrastructure/{domain}/hosted-zone-id
```

### Repository Naming Convention

Content projects follow the naming pattern:
- Repository: `website_{domain-with-underscores}_com`
- Example: `website_denverbytes_com` → `denverbytes.com`

## Content Project Structure

A typical content project includes:

```
website_example_com/
├── src/                    # Source content
├── dist/                   # Built static files
├── scripts/
│   ├── deploy.sh          # Content deployment script
│   ├── verify-prerequisites.sh
│   └── list-deployed-resources.sh
├── package.json           # Build dependencies
└── README.md
```

## Deployment Workflow

### 1. Build Phase

Content projects build static files:
```bash
npm run build  # or equivalent build command
```

### 2. Infrastructure Discovery

Deployment script extracts domain from repository name and retrieves infrastructure parameters:

```bash
# Extract domain from git repository
PROJECT_NAME=$(git remote get-url origin | sed -E 's|.*github\.com[:/][^/]+/([^/.]+)(\.git)?$|\1|')
DOMAIN_STUB=$(echo "$PROJECT_NAME" | sed 's/^website_//' | sed 's/_com$//')
DOMAIN_NAME="${DOMAIN_STUB}.com"

# Get infrastructure parameters
BUCKET_NAME=$(aws ssm get-parameter --name "/static-website/infrastructure/${DOMAIN_NAME}/bucket-name" --query Parameter.Value --output text)
DISTRIBUTION_ID=$(aws ssm get-parameter --name "/static-website/infrastructure/${DOMAIN_NAME}/cloudfront-distribution-id" --query Parameter.Value --output text)
```

### 3. Content Upload

Upload built files to S3:
```bash
aws s3 sync dist/ s3://${BUCKET_NAME}/ --delete
```

### 4. Cache Invalidation

Clear CloudFront cache:
```bash
aws cloudfront create-invalidation --distribution-id ${DISTRIBUTION_ID} --paths "/*"
```

## Reference Implementation

See [website_denverbytes_com](https://github.com/stephenabbot/website_denverbytes_com) for a complete reference implementation using:
- Astro static site generator
- TypeScript for type safety
- GitHub Actions for automated deployment
- Proper error handling and rollback capabilities

## Security Integration

Content projects use the same deployment role pattern:
- Role ARN stored in SSM: `/deployment-roles/{project-name}/role-arn`
- OIDC-based GitHub Actions authentication
- No hardcoded AWS resource identifiers

## GitHub Actions Integration

Example workflow for automated content deployment:

```yaml
name: Deploy Website
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/gharole-website-example-com-prd
          aws-region: us-east-1
      
      - name: Deploy content
        run: ./scripts/deploy.sh
```

## Troubleshooting

### Common Issues

**SSM Parameter Not Found**
- Ensure infrastructure project has been deployed
- Verify domain name matches exactly
- Check AWS region (parameters are in us-east-1)

**S3 Upload Failures**
- Verify deployment role has S3 permissions
- Check bucket name is correct
- Ensure built files exist in expected directory

**CloudFront Invalidation Errors**
- Verify distribution ID is correct
- Check CloudFront permissions in deployment role
- Wait for previous invalidations to complete

For additional troubleshooting, see the infrastructure project's [troubleshooting guide](https://github.com/stephenabbot/website-infrastructure/blob/main/docs/troubleshooting.md).
