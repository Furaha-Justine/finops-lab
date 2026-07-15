terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket         = "fincorp-terraform-state-976193229864"
    key            = "fincorp/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "fincorp-terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "dr"
  region = var.dr_region
}
