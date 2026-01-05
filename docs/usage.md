# Usage Guide

## Domain Creation

Create a new domain configuration using the domain creation script:

```bash
./scripts/create-domain.sh example.com
```

This creates the directory structure:
```
projects/
└── example-com/
    └── prd/
        └── domain.tf
```

### Domain Naming Convention

- Dots are converted to hyphens for directory names
- `example.com` becomes `example-com`
- Only production (`prd`) environment is currently supported

## Infrastructure Deployment

Deploy infrastructure for all configured domains:

```bash
./scripts/deploy.sh
```

The deployment process:
1. Verifies prerequisites and AWS credentials
2. Configures Terraform backend from SSM parameters
3. Discovers all domain configurations automatically
4. Deploys infrastructure for each domain in parallel
5. Publishes resource identifiers to SSM Parameter Store

### Deployment Outputs

After successful deployment, the following resources are created for each domain:
- S3 bucket for static content
- CloudFront distribution with custom domain
- ACM certificate for apex and www subdomains
- Route53 hosted zone with DNS records
- SSM parameters for content project integration

## Resource Management

### List Deployed Resources

View all deployed resources:

```bash
./scripts/list-deployed-resources.sh
```

### Destroy Infrastructure

Remove all infrastructure (use with caution):

```bash
./scripts/destroy.sh
```

## Script Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| `create-domain.sh` | Create new domain configuration | `./scripts/create-domain.sh domain.com` |
| `deploy.sh` | Deploy all domain infrastructure | `./scripts/deploy.sh` |
| `list-deployed-resources.sh` | List deployed resources | `./scripts/list-deployed-resources.sh` |
| `destroy.sh` | Destroy all infrastructure | `./scripts/destroy.sh` |
| `verify-prerequisites.sh` | Check system requirements | `./scripts/verify-prerequisites.sh` |

All scripts include built-in help and validation. Run any script without arguments to see usage information.
