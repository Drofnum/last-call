# Cloud Deployment Challenge - Solution

## Overview

This solution hosts the static website content from the `web/` directory on AWS using Terraform for infrastructure provisioning. The website is served through CloudFront with S3 as the origin, and is protected with HTTP Basic Authentication using Lambda@Edge.

### Features

- **Infrastructure as Code**: All AWS resources are defined using Terraform
- **Security**: HTTP Basic Authentication protects the site from unauthorized access
- **CI/CD**: Automated deployment through GitHub Actions
- **Automated Updates**: Changes to the website in the repository will automatically be deployed
- **Cost Effective**: Uses S3 for storage and minimal CloudFront resources

## Authentication

The website is protected with HTTP Basic Authentication:
- **Username**: lcm-user
- **Password**: lcm-challenge

## Implementation Details

The solution consists of:

1. **S3 Bucket**: Stores the website content from the `web/` directory
2. **CloudFront Distribution**: Serves the content with caching and HTTPS
3. **Lambda@Edge**: Implements HTTP Basic Authentication on all requests
4. **GitHub Actions**: Automates deployment when changes are pushed

## AWS Credentials Management

There are two methods for authentication with AWS:

1. **GitHub Actions Integration**:
   - Set up AWS access key and secret key as GitHub repository secrets
   - GitHub Actions workflow uses these credentials to authenticate with AWS

2. **credentials.sh Script**:
   - Provided in the repository to convert temporary AWS credentials into permanent ones
   - Useful for running Terraform commands locally or setting up GitHub Actions

## Error Prevention and Handling

The solution includes several safeguards to ensure reliable operation:

1. **Lambda Function Generation**:
   - The Lambda function code is generated dynamically during deployment
   - This ensures the authentication code is always available regardless of where the pipeline runs

2. **S3 Bucket Verification**:
   - The update workflow checks if the S3 bucket exists before attempting to upload files
   - If the bucket doesn't exist, it gracefully handles the failure

3. **CloudFront Distribution Detection**:
   - Multiple strategies to find the correct CloudFront distribution for cache invalidation
   - Includes detailed logging to help troubleshoot any issues

4. **Proper Resource Dependencies**:
   - Terraform configuration includes explicit dependencies between resources
   - This ensures resources are created in the correct order

## Security Considerations

In a production environment, I would make these improvements:
- Store credentials in AWS Secrets Manager and load them dynamically
- Add WAF rules to protect against common web attacks
- Configure more restrictive bucket policies and IAM roles
- Implement proper SSL certificates (currently using CloudFront's default)
- Use more restricted IAM policies instead of AdministratorAccess
- Implement a rotation mechanism for the AWS access keys

## Deployment Process

The solution is deployed automatically via GitHub Actions when changes are pushed to the main branch. A separate workflow is triggered when changes are made to the web content only, which updates the S3 bucket without redeploying the entire infrastructure.

## Architecture

```
┌───────────┐    ┌─────────────┐    ┌──────────────┐    ┌───────────┐
│           │    │             │    │              │    │           │
│  User     ├───►│ CloudFront  ├───►│ Lambda@Edge  ├───►│ S3 Bucket │
│  Browser  │    │ Distribution│    │ Basic Auth   │    │ Web Files │
│           │    │             │    │              │    │           │
└───────────┘    └─────────────┘    └──────────────┘    └───────────┘
``` 