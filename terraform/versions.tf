terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }

  # Bucket, Schlüssel und Region kommen aus backend.hcl, siehe backend.hcl.example.
  # use_lockfile sperrt den State über eine Datei in S3, eine DynamoDB-Tabelle ist nicht nötig.
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
