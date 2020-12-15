terraform {
  backend "s3" {
    region = "eu-west-1"
  }
}

provider "aws" {
  version = ">= 1.51.0"

  allowed_account_ids = ["${var.aws_account_id}"]
  assume_role {
    role_arn  = "${var.aws_assume_role_arn}"
  }
  region     = "eu-west-1"
}
