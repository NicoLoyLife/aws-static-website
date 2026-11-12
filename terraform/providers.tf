provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# CloudFront meldet seine Metriken nur in us-east-1, deshalb liegt der Alarm dort.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Repository = var.github_repository
  }
}
