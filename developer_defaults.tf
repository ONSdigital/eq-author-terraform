variable "env" {
  description = "The environment you wish to use"
}

variable "aws_account_id" {
  description = "Amazon Web Service Account ID"
}

variable "aws_assume_role_arn" {
  description = "IAM Role to assume on AWS"
}

variable "ons_access_ips" {
  description = "List of IP's or IP ranges to allow access to eQ"
}

variable "certificate_arn" {
  description = "ARN of the IAM loaded TLS certificate for public ELB"
}

# DNS
variable "dns_zone_name" {
  description = "Amazon Route53 DNS zone name"
  default     = "dev.eq.ons.digital"
}

// Alerting
variable "slack_webhook_path" {
  description = "Slack Webhook path for the alert. Obtained via, https://api.slack.com/incoming-webhooks"
}

// Runner
variable "survey_runner_keys_file_name" {
  description = "The filename of the file containing the application keys"
  default     = "docker-keys.yml"
}

variable "survey_runner_secrets_file_name" {
  description = "The filename of the file containing the application secrets"
  default     = "docker-secrets.yml"
}

variable "survey_runner_docker_registry" {
  description = "The docker repository for the Survey Runner image"
  default     = "onsdigital"
}

variable "survey_runner_tag" {
  description = "The tag for the Survey Runner image to run"
  default     = "latest"
}

variable "survey_runner_min_tasks" {
  description = "The minimum number of Survey Runner tasks to run"
  default     = "1"
}

variable "respondent_account_url" {
  description = "The url for the respondent log in"
  default     = "https://survey.ons.gov.uk/"
}

variable "survey_runner_log_level" {
  description = "The Survey Runner logging level (One of ['CRITICAL', 'ERROR', 'WARNING', 'INFO', 'DEBUG'])"
  default     = "INFO"
}

// RDS
variable "database_instance_class" {
  description = "The size of the DB instance"
  default     = "db.t2.small"
}

variable "database_allocated_storage" {
  description = "The allocated storage for the database (in GB)"
  default     = 10
}

variable "database_free_memory_alert_level" {
  description = "The level at which to alert about lack of freeable memory (MB)"
  default     = 128
}

variable "database_apply_immediately" {
  description = "Apply changes to the database immediately and not during next maintenance window"
  default     = true
}

variable "author_database_name" {
  description = "The name of the author database"
  default     = "author"
}

variable "author_database_user" {
  description = "The name of the author database user"
  default     = "author"
}

variable "author_database_password" {
  description = "The password of the author database user"
  default     = "digitaleq"
}

variable "multi_az" {
  description = "Distribute database across multiple availability zones"
  default     = false
}

variable "backup_retention_period" {
  description = "How many days database backup to keep"
  default     = 0
}

// Author
variable "author_database" {
  description = "which database to use (dynamodb, mongodb, firestore)"
  default     = "dynamodb"
}

variable "author_mongo_username" {
  description = "username for mongodb"
}

variable "author_mongo_password" {
  description = "password for mongodb"
}

variable "author_mongo_databasename" {
  description = "database name for mongodb"
  default = "author"
}

variable "author_vpc_cidr_block" {
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "author_public_cidrs" {
  type        = "list"
  description = "CIDR blocks for public subnets"
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "author_database_cidrs" {
  type        = "list"
  description = "CIDR blocks for database subnets"
  default     = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
}

variable "author_application_cidrs" {
  type        = "list"
  description = "CIDR blocks for application subnets"
  default     = ["10.0.64.0/18", "10.0.128.0/18", "10.0.192.0/18"]
}

variable "author_registry" {
  description = "The docker repository for the author images to run"
  default     = "onsdigital"
}

variable "author_tag" {
  description = "The tag for the Author image to run"
  default     = "latest"
}

variable "author_firebase_project_id" {
  description = "The Firebase authentication project id"
}

variable "author_firebase_api_key" {
  description = "The Firebase authentication API key"
}

variable "author_gtm_id" {
  description = "The Google Tag Manager container ID"
  default     = ""
}

variable "author_gtm_auth" {
  description = "The Google Tag Manager environment ID"
  default     = ""
}

variable "author_gtm_preview" {
  description = "The Google Tag Manager preview environment"
  default     = ""
}

variable "author_sentry_dsn" {
  description = "The Sentry Project dsn"
  default     = ""
}

variable "author_api_enable_import" {
  description = "Whether to enable the import endpoint on the api"
  default     = "false"
}

variable "author_min_tasks" {
  description = "The minimum number of Author tasks to run"
  default     = "1"
}

variable "author_api_min_tasks" {
  description = "The minimum number of Author API tasks to run"
  default     = "1"
}

variable "author_api_allowed_email_list" {
  description = "The minimum number of Author API tasks to run"
  default     = "@ons.gov.uk, @ext.ons.gov.uk, @nisra.gov.uk"
}

variable "publisher_min_tasks" {
  description = "The minimum number of Publisher tasks to run"
  default     = "1"
}

variable "survey_launcher_tag" {
  description = "The tag for the Survey Launcher image to run"
  default     = "latest"
}

variable "survey_launcher_jwt_encryption_key_path" {
  description = "Path to the JWT Encryption Key (PEM format)"
  default     = "jwt-test-keys/sdc-user-authentication-encryption-sr-public-key.pem"
}

variable "survey_launcher_jwt_signing_key_path" {
  description = "Path to the JWT Signing Key (PEM format)"
  default     = "jwt-test-keys/sdc-user-authentication-signing-launcher-private-key.pem"
}

variable "register_tag" {
  description = "The tag for the Survey Register image to run"
  default     = "latest"
}

variable "survey_register_min_tasks" {
  description = "The minimum number of Survey Register tasks to run"
  default     = "1"
}

variable "survey_launcher_min_tasks" {
  description = "The minimum number of Survey Launcher tasks to run"
  default     = "1"
}

variable "survey_launcher_s3_secrets_bucket" {
  description = "The S3 bucket that contains the secrets"
  default     = ""
}

// Schema Validator
variable "schema_validator_registry" {
  description = "The docker repository for the Schema Validator image to run"
  default     = "onsdigital"
}

variable "schema_validator_tag" {
  description = "The tag for the Schema Validator image to run"
  default     = "latest"
}

variable "schema_validator_min_tasks" {
  description = "The minimum number of Schema Validator tasks to run"
  default     = "1"
}

// ECS
variable "create_ecs_external_elb" {
  description = "Deploy an external load balancer for ECS"
  default     = true
}

variable "create_ecs_internal_elb" {
  description = "Deploy an internal load balancer for ECS"
  default     = false
}

//survey register
variable "survey_register_registry" {
  description = "The docker repository for the survey register images to run"
  default     = "onsdigital"
}
