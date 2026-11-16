# AWS deployment

This infrastructure demonstrates S3 storage and ECS Fargate deployment. It creates billable AWS resources, including a load balancer and a running Fargate task.

## Prerequisites

- AWS account and AWS CLI authentication
- Docker
- Terraform 1.6 or newer
- permission to create VPC, IAM, S3, ECR, ECS, CloudWatch, and load-balancer resources

## First deployment

The ECR repository must exist before the first application image can be pushed. Run the deployment in this order from the repository root:

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply -target=aws_ecr_repository.app -target=aws_s3_bucket.data
```

Retrieve the ECR URL and push the first image:

```bash
ECR_URL=$(terraform output -raw ecr_repository_url)
AWS_ACCOUNT_REGISTRY=$(printf '%s' "$ECR_URL" | cut -d/ -f1)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin "$AWS_ACCOUNT_REGISTRY"
cd ..
docker build -t microbiome-explorer .
docker tag microbiome-explorer:latest "$ECR_URL:latest"
docker push "$ECR_URL:latest"
cd infra
terraform apply
terraform output -raw application_url
```

If `aws_region` is changed in `terraform.tfvars`, use the same region in the ECR login command.

## GitHub deployment variables

After the first deployment, configure these GitHub repository variables:

| Variable | Value |
|---|---|
| `AWS_REGION` | Terraform `aws_region` |
| `ECR_REPOSITORY` | `microbiome-explorer` |
| `ECS_CLUSTER` | output `ecs_cluster_name` |
| `ECS_SERVICE` | output `ecs_service_name` |
| `ECS_TASK_DEFINITION` | `microbiome-explorer` |

Configure the secret `AWS_ROLE_ARN` with an AWS IAM role trusted by GitHub OIDC and authorized to push ECR images and update the ECS service. Do not store long-lived AWS access keys in the repository.

## Remove resources

```bash
terraform destroy
```

The versioned S3 bucket must be empty before Terraform can delete it. Download any needed analysis bundles and remove all object versions before destruction.
