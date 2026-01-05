# Resource Tagging

## Standard Tags Applied

All resources receive consistent tags through the standard-tags module:

- **Project** - Git project name extracted from repository URL
- **Repository** - Full git repository URL
- **Environment** - Environment identifier (prd, dev, etc.)
- **Owner** - Resource owner (StephenAbbot)
- **DeployedBy** - AWS ARN of deployment principal
- **ManagedBy** - Infrastructure management tool (OpenTofu)
- **DeploymentId** - Deployment identifier (Default)

## Resource-Specific Tags

### S3 Buckets
- **Name** - "Static Website Bucket"
- **Domain** - Associated domain name

### CloudFront Distributions
- **Name** - "Website Distribution"
- **Domain** - Associated domain name

### Route53 Hosted Zones
- **Name** - "Website Hosted Zone"
- **Domain** - Associated domain name

### Route53 Domain Registrations
- **Name** - "Website Domain Registration"
- **Domain** - Associated domain name

### ACM Certificates
- **Name** - "Website Certificate"
- **Domain** - Associated domain name

## Tag Usage

Tags enable:

- Cost allocation by project, environment, and domain
- Resource ownership tracking
- Automated resource management
- Compliance reporting
- Operational visibility

## Tag Consistency

The standard-tags module ensures consistent tagging across all resources within each domain-environment combination while allowing resource-specific tags to be added as needed.
