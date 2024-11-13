terraform {
  required_version = ">= 1.0"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.44.1"
    }
  }

  backend "s3" {
    bucket = "venly-github-actions-tf-states"
    key    = "monitoring/qa/terraform.tfstate"
    region = "eu-west-1"
  }
}
