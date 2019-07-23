terraform {
  required_version = ">= 0.10.0, < 0.11.0"

  backend "s3" {
    bucket = "eq-author-terraform-state"
    region = "eu-west-1"
  }
}

module "author-vpc" {
  source                     = "github.com/ONSdigital/eq-terraform?ref=23.0.0/survey-runner-vpc"
  env                        = "${var.env}"
  aws_account_id             = "${var.aws_account_id}"
  aws_assume_role_arn        = "${var.aws_assume_role_arn}"
  vpc_name                   = "author"
  vpc_cidr_block             = "${var.author_vpc_cidr_block}"
  database_cidrs             = "${var.author_database_cidrs}"
  db_subnet_group_identifier = "author-"
}

module "author-routing" {
  source              = "github.com/ONSdigital/eq-terraform/survey-runner-routing"
  env                 = "${var.env}"
  aws_account_id      = "${var.aws_account_id}"
  aws_assume_role_arn = "${var.aws_assume_role_arn}"
  public_cidrs        = "${var.author_public_cidrs}"
  vpc_id              = "${module.author-vpc.vpc_id}"
  internet_gateway_id = "${module.author-vpc.internet_gateway_id}"
  database_subnet_ids = "${module.author-vpc.database_subnet_ids}"
}

module "eq-alerting" {
  source              = "github.com/ONSdigital/eq-terraform/survey-runner-alerting"
  env                 = "${var.env}-author"
  aws_account_id      = "${var.aws_account_id}"
  aws_assume_role_arn = "${var.aws_assume_role_arn}"
  slack_webhook_path  = "${var.slack_webhook_path}"
  slack_channel       = "eq-${var.env}-alerts"
}

module "author-eq-ecs" {
  source                  = "github.com/ONSdigital/eq-terraform-ecs?ref=v7.2"
  env                     = "${var.env}"
  ecs_cluster_name        = "eq-author"
  aws_account_id          = "${var.aws_account_id}"
  aws_assume_role_arn     = "${var.aws_assume_role_arn}"
  certificate_arn         = "${var.certificate_arn}"
  vpc_id                  = "${module.author-vpc.vpc_id}"
  public_subnet_ids       = "${module.author-routing.public_subnet_ids}"
  ecs_application_cidrs   = "${var.author_application_cidrs}"
  private_route_table_ids = "${module.author-routing.private_route_table_ids}"
  ecs_cluster_min_size    = 0
  ecs_cluster_max_size    = 0
  ons_access_ips          = ["${split(",", var.ons_access_ips)}"]
  gateway_ips             = ["${module.author-routing.nat_gateway_ips}"]
  create_external_elb     = "${var.create_ecs_external_elb}"
  create_internal_elb     = "${var.create_ecs_internal_elb}"
}

module "author-survey-runner" {
  source                 = "github.com/ONSdigital/eq-ecs-deploy?ref=v4.1"
  env                    = "${var.env}"
  aws_account_id         = "${var.aws_account_id}"
  aws_assume_role_arn    = "${var.aws_assume_role_arn}"
  vpc_id                 = "${module.author-vpc.vpc_id}"
  dns_zone_name          = "${var.dns_zone_name}"
  ecs_cluster_name       = "${module.author-eq-ecs.ecs_cluster_name}"
  aws_alb_arn            = "${module.author-eq-ecs.aws_external_alb_arn}"
  aws_alb_listener_arn   = "${module.author-eq-ecs.aws_external_alb_listener_arn}"
  service_name           = "author-surveys"
  listener_rule_priority = 200
  docker_registry        = "${var.survey_runner_docker_registry}"
  container_name         = "eq-survey-runner"
  container_port         = 5000
  healthcheck_path       = "/status"
  container_tag          = "${var.survey_runner_tag}"
  application_min_tasks  = "${var.survey_runner_min_tasks}"
  slack_alert_sns_arn    = "${module.eq-alerting.slack_alert_sns_arn}"
  ecs_subnet_ids         = "${module.author-eq-ecs.ecs_subnet_ids}"
  ecs_alb_security_group = ["${module.author-eq-ecs.ecs_alb_security_group}"]
  launch_type            = "FARGATE"

  container_environment_variables = <<EOF
      {
        "name": "EQ_RABBITMQ_ENABLED",
        "value": "False"
      },
      {
        "name": "EQ_RABBITMQ_HOST",
        "value": ""
      },
      {
        "name": "EQ_RABBITMQ_HOST_SECONDARY",
        "value": ""
      },
      {
        "name": "SQLALCHEMY_DATABASE_URI",
        "value": "sqlite:////tmp/questionnaire.db"
      },
      {
        "name": "EQ_LOG_LEVEL",
        "value": "${var.survey_runner_log_level}"
      },
      {
        "name": "EQ_KEYS_FILE",
        "value": "${var.survey_runner_keys_file_name}"
      },
      {
        "name": "EQ_SECRETS_FILE",
        "value": "${var.survey_runner_secrets_file_name}"
      },
      {
        "name": "RESPONDENT_ACCOUNT_URL",
        "value": "${var.respondent_account_url}"
      },
      {
        "name": "EQ_SUBMITTED_RESPONSES_TABLE_NAME",
        "value": "${module.author-survey-runner-dynamodb.submitted_responses_table_name}"
      },
      {
        "name": "EQ_QUESTIONNAIRE_STATE_TABLE_NAME",
        "value": "${module.author-survey-runner-dynamodb.questionnaire_state_table_name}"
      },
      {
        "name": "EQ_QUESTIONNAIRE_STATE_DYNAMO_READ",
        "value": "True"
      },
      {
        "name": "EQ_QUESTIONNAIRE_STATE_DYNAMO_WRITE",
        "value": "True"
      },
      {
        "name": "EQ_SESSION_TABLE_NAME",
        "value": "${module.author-survey-runner-dynamodb.eq_session_table_name}"
      },
      {
        "name": "EQ_SESSION_DYNAMO_READ",
        "value": "True"
      },
      {
        "name": "EQ_SESSION_DYNAMO_WRITE",
        "value": "True"
      },
      {
        "name": "EQ_USED_JTI_CLAIM_TABLE_NAME",
        "value": "${module.author-survey-runner-dynamodb.used_jti_claim_table_name}"
      },
      {
        "name": "EQ_USED_JTI_CLAIM_DYNAMO_READ",
        "value": "True"
      },
      {
        "name": "EQ_USED_JTI_CLAIM_DYNAMO_WRITE",
        "value": "True"
      }
  EOF

  task_has_iam_policy = true

  task_iam_policy_json = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Sid": "",
          "Effect": "Allow",
          "Action": [
              "dynamodb:PutItem",
              "dynamodb:GetItem"
          ],
          "Resource": "${module.author-survey-runner-dynamodb.submitted_responses_table_arn}"
      },
      {
          "Sid": "",
          "Effect": "Allow",
          "Action": [
              "dynamodb:PutItem",
              "dynamodb:GetItem",
              "dynamodb:DeleteItem"
          ],
          "Resource": "${module.author-survey-runner-dynamodb.questionnaire_state_table_arn}"
      },
      {
          "Sid": "",
          "Effect": "Allow",
          "Action": [
              "dynamodb:PutItem",
              "dynamodb:GetItem",
              "dynamodb:DeleteItem"
          ],
          "Resource": "${module.author-survey-runner-dynamodb.eq_session_table_arn}"
      },
      {
          "Sid": "",
          "Effect": "Allow",
          "Action": [
              "dynamodb:PutItem"
          ],
          "Resource": "${module.author-survey-runner-dynamodb.used_jti_claim_table_arn}"
      }

  ]
}
  EOF
}

module "author-survey-runner-static" {
  source                     = "github.com/ONSdigital/eq-ecs-deploy?ref=v4.1"
  env                        = "${var.env}"
  aws_account_id             = "${var.aws_account_id}"
  aws_assume_role_arn        = "${var.aws_assume_role_arn}"
  vpc_id                     = "${module.author-vpc.vpc_id}"
  dns_zone_name              = "${var.dns_zone_name}"
  dns_record_name            = "${var.env}-author-new-surveys.${var.dns_zone_name}"
  ecs_cluster_name           = "${module.author-eq-ecs.ecs_cluster_name}"
  aws_alb_arn                = "${module.author-eq-ecs.aws_external_alb_arn}"
  aws_alb_listener_arn       = "${module.author-eq-ecs.aws_external_alb_listener_arn}"
  service_name               = "author-surveys-static"
  listener_rule_priority     = 100
  docker_registry            = "${var.survey_runner_docker_registry}"
  container_name             = "eq-survey-runner-static"
  container_port             = 80
  container_tag              = "${var.survey_runner_tag}"
  application_min_tasks      = "${var.survey_runner_min_tasks}"
  slack_alert_sns_arn        = "${module.eq-alerting.slack_alert_sns_arn}"
  alb_listener_path_patterns = ["/s/*"]
  ecs_subnet_ids             = "${module.author-eq-ecs.ecs_subnet_ids}"
  ecs_alb_security_group     = ["${module.author-eq-ecs.ecs_alb_security_group}"]
  launch_type                = "FARGATE"
  cpu_units                  = "256"
  memory_units               = "512"
}

module "author" {
  source                           = "github.com/ONSdigital/eq-ecs-deploy?ref=v4.1"
  env                              = "${var.env}"
  aws_account_id                   = "${var.aws_account_id}"
  aws_assume_role_arn              = "${var.aws_assume_role_arn}"
  dns_zone_name                    = "${var.dns_zone_name}"
  ecs_cluster_name                 = "${module.author-eq-ecs.ecs_cluster_name}"
  vpc_id                           = "${module.author-vpc.vpc_id}"
  aws_alb_arn                      = "${module.author-eq-ecs.aws_external_alb_arn}"
  aws_alb_listener_arn             = "${module.author-eq-ecs.aws_external_alb_listener_arn}"
  aws_alb_use_host_header          = false
  service_name                     = "author"
  listener_rule_priority           = 900
  docker_registry                  = "${var.author_registry}"
  container_name                   = "eq-author"
  container_port                   = 3000
  container_tag                    = "${var.author_tag}"
  healthcheck_path                 = "/status.json"
  healthcheck_grace_period_seconds = 120
  slack_alert_sns_arn              = "${module.eq-alerting.slack_alert_sns_arn}"
  application_min_tasks            = "${var.author_min_tasks}"
  high_cpu_threshold               = 80
  ecs_subnet_ids                   = "${module.author-eq-ecs.ecs_subnet_ids}"
  ecs_alb_security_group           = ["${module.author-eq-ecs.ecs_alb_security_group}"]
  launch_type                      = "FARGATE"
  cpu_units                        = "256"
  memory_units                     = "512"
  auth_unauth_action               = "authenticate"

  container_environment_variables = <<EOF
      {
        "name": "REACT_APP_AUTH_TYPE",
        "value": "firebase"
      },
      {
        "name": "REACT_APP_API_URL",
        "value": "/graphql"
      },
      {
        "name": "REACT_APP_LAUNCH_URL",
        "value": "https://${var.env}-author.${var.dns_zone_name}/launch"
      },
      {
        "name": "REACT_APP_FIREBASE_PROJECT_ID",
        "value": "${var.author_firebase_project_id}"
      },
      {
        "name": "REACT_APP_FIREBASE_API_KEY",
        "value": "${var.author_firebase_api_key}"
      },
      {
        "name": "REACT_APP_GTM_ID",
        "value": "${var.author_gtm_id}"
      },
      {
        "name": "REACT_APP_GTM_ENV_ID",
        "value": "${var.author_gtm_env_id}"
      },
      {
        "name": "REACT_APP_SENTRY_DSN",
        "value": "${var.author_sentry_dsn}"
      }
  EOF
}

module "author-api" {
  source                     = "github.com/ONSdigital/eq-ecs-deploy?ref=v4.1"
  env                        = "${var.env}"
  aws_account_id             = "${var.aws_account_id}"
  aws_assume_role_arn        = "${var.aws_assume_role_arn}"
  dns_zone_name              = "${var.dns_zone_name}"
  dns_record_name            = "${var.env}-author.${var.dns_zone_name}"
  ecs_cluster_name           = "${module.author-eq-ecs.ecs_cluster_name}"
  vpc_id                     = "${module.author-vpc.vpc_id}"
  aws_alb_arn                = "${module.author-eq-ecs.aws_external_alb_arn}"
  aws_alb_listener_arn       = "${module.author-eq-ecs.aws_external_alb_listener_arn}"
  aws_alb_use_host_header    = false
  service_name               = "author-api"
  listener_rule_priority     = 300
  docker_registry            = "${var.author_registry}"
  container_name             = "eq-author-api"
  container_port             = 4000
  container_tag              = "${var.author_tag}"
  healthcheck_path           = "/status"
  application_min_tasks      = "${var.author_api_min_tasks}"
  slack_alert_sns_arn        = "${module.eq-alerting.slack_alert_sns_arn}"
  ecs_subnet_ids             = "${module.author-eq-ecs.ecs_subnet_ids}"
  ecs_alb_security_group     = ["${module.author-eq-ecs.ecs_alb_security_group}"]
  launch_type                = "FARGATE"
  alb_listener_path_patterns = ["/graphql*", "/launch*", "/status", "/export*", "/import*", "/signIn"]
  auth_unauth_action         = "deny"

  container_environment_variables = <<EOF
      {
        "name": "DB_CONNECTION_URI",
        "value": "postgres://${var.author_database_user}:${var.author_database_password}@${module.author-database.database_address}:${module.author-database.database_port}/${var.author_database_name}"
      },
      {
        "name": "RUNNER_SESSION_URL",
        "value": "${module.author-survey-runner.service_address}/session?token="
      },
      {
        "name": "PUBLISHER_URL",
        "value": "${module.publisher.service_address}/publish/"
      },
      {
        "name": "DYNAMO_QUESTIONNAIRE_TABLE_NAME",
        "value": "${module.author-dynamodb.author_questionnaires_table_name}"
      },
      {
        "name": "DYNAMO_QUESTIONNAIRE_VERSION_TABLE_NAME",
        "value": "${module.author-dynamodb.author_questionnaire_versions_table_name}"
      },
      {
        "name": "ENABLE_IMPORT",
        "value": "${var.author_api_enable_import}"
      },
      {
        "name": "DYNAMO_USER_TABLE_NAME",
        "value": "${module.author-dynamodb.author_users_table_name}"
      },
      {
        "name": "FIREBASE_PROJECT_ID",
        "value": "${var.author_firebase_project_id}"
      },
      {
        "name": "REDIS_DOMAIN_NAME",
        "value": "${module.author-redis.author_redis_address}"
      },
      {
        "name": "REDIS_PORT",
        "value": "${module.author-redis.author_redis_port}"
      }
  EOF

  task_has_iam_policy = true

  task_iam_policy_json = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Sid": "",
          "Effect": "Allow",
          "Action": [
              "dynamodb:Scan",
              "dynamodb:DescribeTable",
              "dynamodb:PutItem",
              "dynamodb:UpdateItem",
              "dynamodb:GetItem",
              "dynamodb:DeleteItem"
          ],
          "Resource": "${module.author-dynamodb.author_questionnaires_table_arn}"
      },
      {
          "Sid": "",
          "Effect": "Allow",
          "Action": [
              "dynamodb:DescribeTable",
              "dynamodb:PutItem",
              "dynamodb:GetItem",
              "dynamodb:Query"
          ],
          "Resource": "${module.author-dynamodb.author_questionnaire_versions_table_arn}"
      },
      {
          "Sid": "",
          "Effect": "Allow",
          "Action": [
              "dynamodb:Scan",
              "dynamodb:DescribeTable",
              "dynamodb:PutItem",
              "dynamodb:UpdateItem",
              "dynamodb:GetItem",
              "dynamodb:Query"
          ],
          "Resource": "${module.author-dynamodb.author_users_table_arn}"
      }
  ]
}
  EOF
}

module "publisher" {
  source                 = "github.com/ONSdigital/eq-ecs-deploy?ref=v4.1"
  env                    = "${var.env}"
  aws_account_id         = "${var.aws_account_id}"
  aws_assume_role_arn    = "${var.aws_assume_role_arn}"
  dns_zone_name          = "${var.dns_zone_name}"
  ecs_cluster_name       = "${module.author-eq-ecs.ecs_cluster_name}"
  vpc_id                 = "${module.author-vpc.vpc_id}"
  aws_alb_arn            = "${module.author-eq-ecs.aws_external_alb_arn}"
  aws_alb_listener_arn   = "${module.author-eq-ecs.aws_external_alb_listener_arn}"
  service_name           = "publisher"
  listener_rule_priority = 500
  docker_registry        = "${var.author_registry}"
  container_name         = "eq-publisher"
  container_port         = 9000
  container_tag          = "${var.author_tag}"
  healthcheck_path       = "/status"
  application_min_tasks  = "${var.publisher_min_tasks}"
  slack_alert_sns_arn    = "${module.eq-alerting.slack_alert_sns_arn}"
  ecs_subnet_ids         = "${module.author-eq-ecs.ecs_subnet_ids}"
  ecs_alb_security_group = ["${module.author-eq-ecs.ecs_alb_security_group}"]
  launch_type            = "FARGATE"

  container_environment_variables = <<EOF
      {
        "name": "EQ_AUTHOR_API_URL",
        "value": "${module.author-api.service_address}/graphql"
      },
      {
        "name": "EQ_SCHEMA_VALIDATOR_URL",
        "value": "${module.author-schema-validator.service_address}/validate"
      }
  EOF
}

module "author-schema-validator" {
  source                 = "github.com/ONSdigital/eq-ecs-deploy?ref=v4.1"
  env                    = "${var.env}"
  aws_account_id         = "${var.aws_account_id}"
  aws_assume_role_arn    = "${var.aws_assume_role_arn}"
  vpc_id                 = "${module.author-vpc.vpc_id}"
  dns_zone_name          = "${var.dns_zone_name}"
  ecs_cluster_name       = "${module.author-eq-ecs.ecs_cluster_name}"
  aws_alb_arn            = "${module.author-eq-ecs.aws_external_alb_arn}"
  aws_alb_listener_arn   = "${module.author-eq-ecs.aws_external_alb_listener_arn}"
  service_name           = "author-schema-validator"
  listener_rule_priority = 600
  docker_registry        = "${var.schema_validator_registry}"
  container_name         = "eq-schema-validator"
  container_port         = 5000
  container_tag          = "${var.schema_validator_tag}"
  healthcheck_path       = "/status"
  application_min_tasks  = "${var.schema_validator_min_tasks}"
  slack_alert_sns_arn    = "${module.eq-alerting.slack_alert_sns_arn}"
  ecs_subnet_ids         = "${module.author-eq-ecs.ecs_subnet_ids}"
  ecs_alb_security_group = ["${module.author-eq-ecs.ecs_alb_security_group}"]
  launch_type            = "FARGATE"
  cpu_units              = "256"
  memory_units           = "512"
}

module "author-database" {
  source                           = "github.com/ONSdigital/eq-terraform/survey-runner-database"
  env                              = "${var.env}"
  aws_account_id                   = "${var.aws_account_id}"
  aws_assume_role_arn              = "${var.aws_assume_role_arn}"
  vpc_id                           = "${module.author-vpc.vpc_id}"
  application_cidrs                = "${var.author_application_cidrs}"
  multi_az                         = "${var.multi_az}"
  backup_retention_period          = "${var.backup_retention_period}"
  database_apply_immediately       = "${var.database_apply_immediately}"
  database_instance_class          = "${var.database_instance_class}"
  database_allocated_storage       = "${var.database_allocated_storage}"
  database_free_memory_alert_level = "${var.database_free_memory_alert_level}"
  database_name                    = "${var.author_database_name}"
  database_user                    = "${var.author_database_user}"
  database_password                = "${var.author_database_password}"
  db_subnet_group_name             = "${module.author-vpc.database_subnet_group_name}"
  database_identifier              = "${var.env}-authorrds"
  rds_security_group_name          = "${var.env}-author-rds-access"
  snapshot_identifier              = "pre-migrate-author"
}

module "author-survey-runner-dynamodb" {
  source              = "github.com/ONSdigital/eq-terraform-dynamodb?ref=v2.2"
  env                 = "${var.env}-author"
  aws_account_id      = "${var.aws_account_id}"
  aws_assume_role_arn = "${var.aws_assume_role_arn}"
  slack_alert_sns_arn = "${module.eq-alerting.slack_alert_sns_arn}"
}

module "author-dynamodb" {
  source              = "github.com/ONSdigital/eq-author-terraform-dynamodb?ref=v0.2"
  env                 = "${var.env}-author"
  aws_account_id      = "${var.aws_account_id}"
  aws_assume_role_arn = "${var.aws_assume_role_arn}"
  slack_alert_sns_arn = "${module.eq-alerting.slack_alert_sns_arn}"
}

module "author-redis" {
  source              = "github.com/ONSdigital/eq-author-terraform-redis?ref=v1.0"
  env                 = "${var.env}-author"
  aws_account_id      = "${var.aws_account_id}"
  aws_assume_role_arn = "${var.aws_assume_role_arn}"
  vpc_id              = "${module.author-vpc.vpc_id}"
  application_cidrs   = "${var.author_application_cidrs}"
  database_subnet_ids = "${module.author-vpc.database_subnet_ids}"
}

module "author-waf" {
  source              = "github.com/ONSdigital/eq-author-terraform-waf?ref=v1.1"
  env                 = "${var.env}-author"
  aws_account_id      = "${var.aws_account_id}"
  aws_assume_role_arn = "${var.aws_assume_role_arn}"
  external_alb_arn    = "${module.author-eq-ecs.aws_external_alb_arn}"
  metric_prefix       = "${var.env}Author"
}

output "author_service_address" {
  value = "${module.author.service_address}"
}
