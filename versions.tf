terraform {
  # 1.9 because several inputs validate against other inputs, which needs cross-object
  # references in validation blocks.
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}
