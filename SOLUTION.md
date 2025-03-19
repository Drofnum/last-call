# Cloud Deployment Challenge - Solution

## Authentication

The website is protected with HTTP Basic Authentication:
- **Username**: lcm-user
- **Password**: AJ@1983!

## Implementation Details

The solution consists of:

1. **S3 Bucket**: Stores the website content from the `web/` directory
2. **CloudFront Distribution**: Serves the content with caching and HTTPS
3. **Lambda@Edge**: Implements HTTP Basic Authentication on all requests
4. **GitHub Actions**: Automates deployment when changes are pushed

## Security Considerations

In a production environment, I would make these improvements:
- Store credentials in AWS Secrets Manager and load them dynamically(currently in github actions secrets which is secure but a move to SSM would be my preferred option)
- Would not put creds in a readme/solutions file
- Add WAF rules to protect against common web attacks
- Configure more restrictive bucket policies and IAM roles
- Implement proper SSL certificates (currently using CloudFront's default)
- Use more restricted IAM policies instead of AdministratorAccess
- Implement a rotation mechanism for the AWS access keys

## Deployment Process

The solution is deployed automatically via GitHub Actions when changes are pushed to the main branch. A separate workflow is triggered when changes are made to the web content only, which updates the S3 bucket without redeploying the entire infrastructure.
