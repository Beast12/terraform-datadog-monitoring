# tofu/backend.tf
terraform {
  backend "s3" {
    bucket  = "venly-github-actions-tf-states"
    key     = "monitoring/${local.environment}/terraform.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }
}

# tofu/qa/backend.tf
locals {
  environment = "qa"
}

terraform {
  backend "s3" {
    bucket  = "venly-github-actions-tf-states"
    key     = "monitoring/qa/terraform.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }
}

# tofu/staging/backend.tf
locals {
  environment = "staging"
}

terraform {
  backend "s3" {
    bucket  = "venly-github-actions-tf-states"
    key     = "monitoring/staging/terraform.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }
}

# tofu/prod/backend.tf
locals {
  environment = "prod"
}

terraform {
  backend "s3" {
    bucket  = "venly-github-actions-tf-states"
    key     = "monitoring/prod/terraform.tfstate"
    region  = "eu-west-1"
    encrypt = true
  }
}

# Updated GitHub Actions workflow with backend configuration
