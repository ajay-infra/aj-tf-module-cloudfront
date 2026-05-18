terraform {
  required_version = "= 1.10.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.100.0"
    }
  }

  # Backend configured dynamically by pipelines via -backend-config
  # backend "s3" {
  #   bucket         = "<tf-state-bucket>"
  #   key            = "<env>/cloudfront/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "tf-locks-central"
  #   role_arn       = "arn:aws:iam::ACCOUNT_ID:role/GitHubActions-Terraform"
  # }
}

# CloudFront, WAF (CLOUDFRONT scope), and ACM certs for CloudFront
# must all be provisioned in us-east-1 — this provider enforces that.
provider "aws" {
  region = "us-east-1"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  default_tags {
    tags = local.full_tags
  }
}
