# Troubleshooting Guide

## Common Issues and Solutions

### OIDC Authentication Failures

#### Symptom
GitHub Actions workflow fails with OIDC authentication error:
```
Error: Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

#### Solutions

1. **Verify GitHub Variable**
   ```bash
   gh variable list
   ```
   Should show `AWS_ACCOUNT_ID` with correct account ID.

2. **Run Bootstrap Script**
   ```bash
   ./scripts/bootstrap.sh
   ```

3. **Check Role Exists**
   ```bash
   aws iam get-role --role-name gharole-website-infrastructure-prd
   ```

4. **Verify Trust Policy**
   The role trust policy should allow GitHub Actions from the repository:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
           },
           "StringLike": {
             "token.actions.githubusercontent.com:sub": "repo:stephenabbot/website-infrastructure:*"
           }
         }
       }
     ]
   }
   ```

### State Lock Issues

#### Symptom
Deployment fails with state lock error:
```
Error: Error acquiring the state lock
```

#### Solutions

1. **Automatic Cleanup**
   The deploy script automatically clears stale locks. Wait and retry.

2. **Manual Lock Cleanup**
   ```bash
   # List locks
   aws dynamodb scan --table-name terraform-locks-ACCOUNT-us-east-1 --filter-expression "contains(LockID, :key)" --expression-attribute-values '{"key":{"S":"static-website-infrastructure"}}'
   
   # Delete specific lock
   aws dynamodb delete-item --table-name terraform-locks-ACCOUNT-us-east-1 --key '{"LockID":{"S":"LOCK_ID"}}'
   ```

3. **Force Unlock (Last Resort)**
   ```bash
   tofu force-unlock LOCK_ID
   ```

### Backend Configuration Errors

#### Symptom
```
Error: Failed to get existing workspaces: S3 bucket does not exist
```

#### Solutions

1. **Verify Foundation Infrastructure**
   ```bash
   aws ssm get-parameter --name "/terraform/foundation/s3-state-bucket"
   aws ssm get-parameter --name "/terraform/foundation/dynamodb-lock-table"
   ```

2. **Deploy Foundation Infrastructure**
   If parameters don't exist, deploy the foundation infrastructure first:
   ```bash
   # Clone and deploy foundation project
   git clone https://github.com/stephenabbot/foundation-iam-deploy-roles.git
   cd foundation-iam-deploy-roles
   ./scripts/deploy.sh
   ```

### Resource Already Exists Errors

#### Symptom
```
Error: creating S3 Bucket (domain-com-static-prd): BucketAlreadyExists
```

#### Cause
State inconsistency between local and GitHub Actions deployments.

#### Solutions

1. **Check Backend Key Consistency**
   Verify both local and GitHub Actions use the same state key:
   - Local: `static-website-infrastructure/stephenabbot-website-infrastructure/terraform.tfstate`
   - GitHub Actions: Same pattern

2. **Import Existing Resources**
   ```bash
   tofu import 'module.domains["domain-com-prd"].aws_s3_bucket.website' domain-com-static-prd
   ```

3. **State Refresh**
   ```bash
   tofu refresh
   ```

### Domain Registration Issues

#### Symptom
```
Error: creating Route53 Domains Registered Domain: operation error Route53Domains: RegisterDomain, https response error StatusCode: 400
```

#### Solutions

1. **Check Domain Availability**
   ```bash
   aws route53domains check-domain-availability --domain-name example.com
   ```

2. **Verify Contact Information**
   Ensure AWS account has valid contact information for domain registration.

3. **Check Domain Transfer Lock**
   If transferring existing domain, ensure transfer lock is disabled.

### Certificate Validation Timeouts

#### Symptom
```
Error: waiting for ACM Certificate validation: timeout while waiting for state to become 'ISSUED'
```

#### Solutions

1. **Check DNS Propagation**
   ```bash
   dig _acme-challenge.example.com CNAME
   ```

2. **Verify Route53 Records**
   ```bash
   aws route53 list-resource-record-sets --hosted-zone-id ZONE_ID
   ```

3. **Manual Certificate Validation**
   Check AWS Console for certificate validation status and required DNS records.

### GitHub Actions Workflow Issues

#### Symptom
Workflow fails to start or shows permission errors.

#### Solutions

1. **Check Workflow Permissions**
   Verify workflow has required permissions in `.github/workflows/deploy.yml`:
   ```yaml
   permissions:
     id-token: write
     contents: read
   ```

2. **Verify Repository Settings**
   - Actions are enabled for the repository
   - Workflow permissions allow token to write

3. **Check Branch Protection**
   Ensure branch protection rules don't prevent workflow execution.

### Local Script Failures

#### Symptom
Scripts fail with permission or tool errors.

#### Solutions

1. **Make Scripts Executable**
   ```bash
   chmod +x scripts/*.sh
   ```

2. **Check Tool Installation**
   ```bash
   ./scripts/verify-prerequisites.sh
   ```

3. **Verify AWS Credentials**
   ```bash
   aws sts get-caller-identity
   ```

4. **Check Git Repository State**
   ```bash
   git status
   git pull origin main
   ```

### CloudFront Distribution Issues

#### Symptom
CloudFront distribution creation fails or shows errors.

#### Solutions

1. **Check Origin Access Control**
   Verify OAC is created before distribution:
   ```bash
   aws cloudfront list-origin-access-controls
   ```

2. **Verify S3 Bucket Policy**
   Ensure bucket policy allows CloudFront access:
   ```bash
   aws s3api get-bucket-policy --bucket domain-com-static-prd
   ```

3. **Check Certificate Status**
   Verify SSL certificate is validated:
   ```bash
   aws acm list-certificates --region us-east-1
   ```

### DNS Resolution Issues

#### Symptom
Domain doesn't resolve or shows incorrect content.

#### Solutions

1. **Check Route53 Records**
   ```bash
   aws route53 list-resource-record-sets --hosted-zone-id ZONE_ID
   ```

2. **Verify Nameservers**
   ```bash
   dig example.com NS
   ```

3. **Test DNS Propagation**
   ```bash
   dig example.com A
   dig example.com AAAA
   ```

4. **Check CloudFront Distribution Status**
   ```bash
   aws cloudfront get-distribution --id DISTRIBUTION_ID
   ```

## Debugging Tools

### Enable Debug Output
Add debug flags to scripts:
```bash
bash -x ./scripts/deploy.sh
```

### OpenTofu Debug
```bash
export TF_LOG=DEBUG
tofu plan
```

### AWS CLI Debug
```bash
aws --debug s3 ls
```

### GitHub Actions Debug
Enable debug logging in workflow:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

## Log Analysis

### GitHub Actions Logs
```bash
# View workflow logs
gh run view RUN_ID --log

# Download logs
gh run download RUN_ID
```

### CloudTrail Events
```bash
# Check recent API calls
aws logs filter-log-events --log-group-name CloudTrail/APIGateway --start-time $(date -d '1 hour ago' +%s)000
```

### CloudFront Logs
Enable CloudFront logging and analyze access patterns:
```bash
aws s3 ls s3://cloudfront-logs-bucket/
```

## Getting Help

### AWS Support
- Use AWS Support Center for infrastructure issues
- Check AWS Service Health Dashboard
- Review AWS documentation and best practices

### GitHub Support
- Check GitHub Status page
- Review GitHub Actions documentation
- Use GitHub Community forums

### OpenTofu Support
- Check OpenTofu documentation
- Use OpenTofu community forums
- Review provider documentation

### Project-Specific Issues
- Create GitHub issue in repository
- Include relevant logs and error messages
- Provide steps to reproduce the issue

## Prevention Strategies

### Regular Maintenance
- Update tools to latest versions
- Review and rotate credentials
- Monitor AWS costs and usage
- Test disaster recovery procedures

### Monitoring
- Set up CloudWatch alarms for key metrics
- Monitor certificate expiration dates
- Track domain registration renewals
- Review security group and IAM changes

### Documentation
- Keep troubleshooting guide updated
- Document custom configurations
- Maintain runbooks for common procedures
- Record lessons learned from incidents
