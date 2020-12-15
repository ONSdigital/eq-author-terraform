variable "env" {
  description = "The environment you wish to use"
}

variable "aws_account_id" {
  description = "Amazon Web Service Account ID"
}

variable "aws_assume_role_arn" {
  description = "IAM Role to assume on AWS"
}

variable "external_alb_arn" {
  description = "External ALB that should be protected by the WAF"
}

variable "metric_prefix" {
  description = "Prefix that gets applied to the WAF rule metric"
}
