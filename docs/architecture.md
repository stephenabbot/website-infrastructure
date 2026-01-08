# Architecture Guide

## System Overview

This project implements a multi-domain static website hosting platform using AWS managed services. Each domain receives dedicated infrastructure while sharing common patterns and operational procedures.

## Architecture Diagram

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Content       │    │   Infrastructure │    │   Foundation    │
│   Projects      │    │   Project        │    │   Projects      │
│                 │    │                  │    │                 │
│ website_*_com   │───▶│ website-         │───▶│ cfn-foundation  │
│ repositories    │    │ infrastructure   │    │ deployment-roles│
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Component Architecture

### Domain Discovery

The system automatically discovers domain configurations through filesystem scanning:

```hcl
locals {
  domain_paths = fileset("${path.module}/projects", "**/*/domain.tf")
  
  domains = {
    for file_path in local.domain_paths :
    "${split("/", file_path)[0]}-${split("/", file_path)[1]}" => {
      domain_safe  = split("/", file_path)[0]
      environment  = split("/", file_path)[1]
      config_path  = "${path.root}/projects/${file_path}"
    }
  }
}
```

### AWS Resource Architecture

For each domain, the following resources are created:

#### Storage Layer

- **S3 Bucket**: Static content storage with versioning and encryption
- **Bucket Policy**: Restricts access to CloudFront only
- **Public Access Block**: Prevents direct public access

#### Content Delivery

- **CloudFront Distribution**: Global CDN with custom domain
- **Origin Access Control**: Secure S3 access from CloudFront
- **CloudFront Function**: Directory index rewriting and canonical domain redirects
- **Response Headers Policy**: Security headers (HSTS, CSP, etc.)

#### DNS & Certificates

- **Route53 Hosted Zone**: DNS management for domain
- **ACM Certificate**: SSL/TLS for apex and www subdomains
- **DNS Records**: A, AAAA (apex), CNAME (www)
- **Domain Registration**: Automatic nameserver updates

#### Integration

- **SSM Parameters**: Resource identifiers for content projects
- **Standard Tags**: Consistent resource organization

## SEO Architecture

### Canonical Domain Implementation

Each domain implements a canonical URL structure to optimize search engine rankings and prevent duplicate content penalties.

#### The Problem

Search engines treat `example.com` and `www.example.com` as separate websites. Without proper canonicalization:

- SEO authority splits between two identical sites
- Duplicate content penalties reduce search rankings
- Analytics and tracking become fragmented
- User experience becomes inconsistent

#### The Solution

This architecture implements **non-WWW canonical domains** with automatic redirects:

```javascript
// CloudFront Function Implementation
function handler(event) {
    var request = event.request;
    var headers = request.headers;
    var host = headers.host.value;
    var uri = request.uri;
    
    // Redirect www subdomain to apex domain (canonical URL)
    if (host.startsWith('www.')) {
        var canonicalHost = host.replace('www.', '');
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                'location': { value: 'https://' + canonicalHost + uri }
            }
        };
    }
    
    // Directory index handling for canonical requests
    if (uri.endsWith('/')) {
        request.uri += 'index.html';
    }
    else if (!uri.includes('.') && !uri.endsWith('/')) {
        request.uri += '/index.html';
    }
    
    return request;
}
```

#### DNS Configuration

- **Apex Domain (A Record)**: Points to CloudFront distribution
- **WWW Subdomain (CNAME)**: Points to apex domain for DNS resolution
- **CloudFront Function**: Handles HTTP-level redirect from www to apex

#### SEO Benefits

- **Consolidated Authority**: All backlinks and rankings consolidate to one domain
- **No Duplicate Content**: Search engines see only canonical URLs
- **Consistent User Experience**: Users always land on the same domain format
- **Analytics Clarity**: All traffic reports under single domain

#### Implementation Details

- **301 Permanent Redirect**: Tells search engines the canonical version
- **Edge-Level Processing**: CloudFront Functions execute at edge locations
- **Zero Latency Impact**: Redirects happen before origin requests
- **Global Consistency**: Same behavior across all CloudFront edge locations

#### Verification Commands

```bash
# Test canonical domain (should return 200)
curl -I https://denverbytes.com

# Test www redirect (should return 301 with location header)
curl -I https://www.denverbytes.com

# Verify DNS resolution
dig denverbytes.com A +short
dig www.denverbytes.com CNAME +short
```

This implementation ensures optimal SEO performance while maintaining a clean, professional URL structure.

## Security Architecture

### Access Control

- S3 buckets block all public access
- CloudFront Origin Access Control provides exclusive S3 access
- IAM roles with least privilege principles
- OIDC-based deployment authentication

### Security Headers

CloudFront Response Headers Policy applies:

- **HSTS**: Force HTTPS connections
- **CSP**: Content Security Policy for XSS protection
- **X-Frame-Options**: Clickjacking prevention
- **X-Content-Type-Options**: MIME sniffing protection
- **Referrer-Policy**: Control referrer information

### Certificate Management

- ACM certificates with DNS validation
- Automatic renewal through AWS
- Support for apex and www subdomains
- TLS 1.2+ enforcement

## Deployment Architecture

### Infrastructure Deployment

1. **Discovery**: Scan projects directory for domain configurations
2. **Backend**: Configure Terraform state from SSM parameters
3. **Deployment**: Deploy all domains in single Terraform run
4. **Publishing**: Store resource identifiers in SSM

### Content Deployment

1. **Build**: Generate static files from source
2. **Discovery**: Extract domain from repository name
3. **Retrieval**: Get infrastructure parameters from SSM
4. **Upload**: Sync content to S3 bucket
5. **Invalidation**: Clear CloudFront cache

## Integration Patterns

### Loose Coupling

- Infrastructure and content projects are independent
- SSM Parameter Store provides service discovery
- No hardcoded resource identifiers in content projects

### Naming Conventions

- Infrastructure: `projects/{domain-safe}/{environment}/domain.tf`
- Content: `website_{domain-with-underscores}_com`
- Resources: `{domain-safe}-{resource-type}-{environment}`

### State Management

- Centralized Terraform state in S3
- DynamoDB state locking
- Backend configuration from foundation project

## Operational Architecture

### Monitoring

- CloudFront access logs (optional)
- Route53 health checks (optional)
- CloudWatch alarms (optional)

### Backup & Recovery

- S3 versioning for content recovery
- Terraform state backup in S3
- Infrastructure as Code for disaster recovery

### Cost Optimization

- S3 static hosting (serverless)
- CloudFront PriceClass_100 (US/Europe)
- Pay-per-use pricing model
- Efficient caching strategies

## Scalability Considerations

### Horizontal Scaling

- Add new domains by creating domain configurations
- Each domain gets dedicated infrastructure
- Shared operational procedures and patterns

### Performance Scaling

- Global CloudFront edge locations
- Compression and caching optimization
- IPv6 support for modern networks

### Operational Scaling

- Automated deployment pipelines
- Consistent tagging for resource management
- SSM Parameter Store for service discovery

## Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Infrastructure** | OpenTofu/Terraform | Infrastructure as Code |
| **Storage** | AWS S3 | Static content hosting |
| **CDN** | AWS CloudFront | Global content delivery |
| **DNS** | AWS Route53 | Domain management |
| **Certificates** | AWS ACM | SSL/TLS management |
| **Integration** | AWS SSM | Service discovery |
| **Deployment** | GitHub Actions | CI/CD automation |
| **Authentication** | GitHub OIDC | Secure deployment |

This architecture provides a scalable, secure, and cost-effective platform for hosting multiple static websites with enterprise-grade operational practices.
