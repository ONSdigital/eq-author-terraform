terraform {
  required_version = ">= 0.10.0, < 0.11.16"

  backend "s3" {
    bucket = "eq-author-terraform-state"
    region = "eu-west-1"
  }
}

module "author-vpc" {
  source                           = "./aws-vpc"
  env                              = "${var.env}"
  aws_account_id                   = "${var.aws_account_id}"
  aws_assume_role_arn              = "${var.aws_assume_role_arn}"
  vpc_name                         = "author"
  vpc_cidr_block                   = "${var.author_vpc_cidr_block}"
  database_cidrs                   = "${var.author_database_cidrs}"
  database_subnet_group_identifier = "author-"
}

module "author-routing" {
  source              = "./aws-routing"
  env                 = "${var.env}"
  aws_account_id      = "${var.aws_account_id}"
  aws_assume_role_arn = "${var.aws_assume_role_arn}"
  public_cidrs        = "${var.author_public_cidrs}"
  vpc_id              = "${module.author-vpc.vpc_id}"
  internet_gateway_id = "${module.author-vpc.internet_gateway_id}"
  database_subnet_ids = "${module.author-vpc.database_subnet_ids}"
}

module "eq-alerting" {
  source              = "./aws-alerting"
  env                 = "${var.env}-author"
  aws_account_id      = "${var.aws_account_id}"
  aws_assume_role_arn = "${var.aws_assume_role_arn}"
  slack_webhook_path  = "${var.slack_webhook_path}"
  slack_channel       = "author-${var.env}-alerts"
}

module "author-eq-ecs" {
  source                  = "github.com/ONSdigital/eq-terraform-ecs?ref=v7.4"
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

module "author-survey-launcher" {
  source                 = "github.com/ONSdigital/eq-ecs-deploy?ref=v4.1"
  env                    = "${var.env}"
  aws_account_id         = "${var.aws_account_id}"
  aws_assume_role_arn    = "${var.aws_assume_role_arn}"
  vpc_id                 = "${module.author-vpc.vpc_id}"
  dns_zone_name          = "${var.dns_zone_name}"
  ecs_cluster_name       = "${module.author-eq-ecs.ecs_cluster_name}"
  aws_alb_arn            = "${module.author-eq-ecs.aws_external_alb_arn}"
  aws_alb_listener_arn   = "${module.author-eq-ecs.aws_external_alb_listener_arn}"
  service_name           = "author-launch"
  listener_rule_priority = 700
  docker_registry        = "${var.survey_runner_docker_registry}"
  container_name         = "go-launch-a-survey"
  container_port         = 8000
  healthcheck_path       = "/status"
  container_tag          = "${var.survey_launcher_tag}"
  application_min_tasks  = "${var.survey_launcher_min_tasks}"
  ecs_subnet_ids         = "${module.author-eq-ecs.ecs_subnet_ids}"
  ecs_alb_security_group = ["${module.author-eq-ecs.ecs_alb_security_group}"]
  launch_type            = "FARGATE"
  slack_alert_sns_arn    = "${module.eq-alerting.slack_alert_sns_arn}"

  container_environment_variables = <<EOF
      {
        "name": "SURVEY_RUNNER_URL",
        "value": "${module.author-survey-runner.service_address}"
      },
      {
        "name": "SCHEMA_VALIDATOR_URL",
        "value": "${module.author-schema-validator.service_address}"
      },
      {
        "name": "JWT_ENCRYPTION_KEY_PATH",
        "value": "${var.survey_launcher_jwt_encryption_key_path}"
      },
      {
        "name": "JWT_SIGNING_KEY_PATH",
        "value": "${var.survey_launcher_jwt_signing_key_path}"
      },
      {
        "name": "SECRETS_S3_BUCKET",
        "value": "${var.survey_launcher_s3_secrets_bucket}"
      },
      {
        "name": "SURVEY_REGISTER_URL",
        "value": "${module.survey-register.service_address}"
      }
  EOF
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
        "name": "REACT_APP_GTM_AUTH",
        "value": "${var.author_gtm_auth}"
      },
      {
        "name": "REACT_APP_GTM_PREVIEW",
        "value": "${var.author_gtm_preview}"
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
  listener_rule_priority     = 800
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
        "name": "RUNNER_SESSION_URL",
        "value": "${module.author-survey-runner.service_address}/session?token="
      },
      {
        "name": "PUBLISHER_URL",
        "value": "${module.publisher.service_address}/publish/"
      },
      {
        "name": "SURVEY_REGISTER_URL",
        "value": "${module.survey-register.service_address}/submit/"
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
        "name": "DYNAMO_COMMENTS_TABLE_NAME",
        "value": "${module.author-dynamodb.author_comments_table_name}"
      },
      {
        "name": "DYNAMO_USER_TABLE_NAME",
        "value": "${module.author-dynamodb.author_users_table_name}"
      },
      {
        "name": "ENABLE_IMPORT",
        "value": "${var.author_api_enable_import}"
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
      },
      {
        "name": "ALLOWED_EMAIL_LIST",
        "value": "${var.author_api_allowed_email_list}"
      },
      {
        "name": "DATABASE",
        "value": "${var.author_database}"
      },
      {
        "name": "MONGO_URL",
        "value": "mongodb://${var.author_mongo_username}:${var.author_mongo_password}@${module.author-documentdb.documentdb_cluster_endpoint}:27017/${var.author_mongo_databasename}?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
      }
  EOF

  task_has_iam_policy = false
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
  listener_rule_priority = 300
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

module "survey-register" {
  source                 = "github.com/ONSdigital/eq-ecs-deploy?ref=v4.1"
  env                    = "${var.env}"
  aws_account_id         = "${var.aws_account_id}"
  aws_assume_role_arn    = "${var.aws_assume_role_arn}"
  dns_zone_name          = "${var.dns_zone_name}"
  ecs_cluster_name       = "${module.author-eq-ecs.ecs_cluster_name}"
  vpc_id                 = "${module.author-vpc.vpc_id}"
  aws_alb_arn            = "${module.author-eq-ecs.aws_external_alb_arn}"
  aws_alb_listener_arn   = "${module.author-eq-ecs.aws_external_alb_listener_arn}"
  service_name           = "author-survey-register"
  listener_rule_priority = 600
  docker_registry        = "${var.survey_register_registry}"
  container_name         = "eq-survey-register"
  container_port         = 8080
  container_tag          = "${var.register_tag}"
  healthcheck_path       = "/status"
  application_min_tasks  = "${var.survey_register_min_tasks}"
  slack_alert_sns_arn    = "${module.eq-alerting.slack_alert_sns_arn}"
  ecs_subnet_ids         = "${module.author-eq-ecs.ecs_subnet_ids}"
  ecs_alb_security_group = ["${module.author-eq-ecs.ecs_alb_security_group}"]
  launch_type            = "FARGATE"

  container_environment_variables = <<EOF
      {
        "name": "DYNAMO_SURVEY_REGISTRY_TABLE_NAME",
        "value": "${module.author-dynamodb.survey_registry_table_name}"
      },
      {
        "name": "SURVEY_REGISTER_URL",
        "value": "${module.survey-register.service_address}"
      },
      {
        "name": "GO_QUICK_LAUNCHER_URL",
        "value": "${module.author-survey-launcher.service_address}/quick-launch?url="
      },
      {
        "name": "PUBLISHER_URL",
        "value": "${module.publisher.service_address}/publish/"
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
              "dynamodb:Query"
          ],
          "Resource": ["${module.author-dynamodb.survey_registry_table_arn}", "${module.author-dynamodb.survey_registry_table_arn}/index/sortKey"]
      }
  ]
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
  listener_rule_priority = 500
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

module "author-survey-runner-dynamodb" {
  source              = "github.com/ONSdigital/eq-terraform-dynamodb?ref=v2.2"
  env                 = "${var.env}-author"
  aws_account_id      = "${var.aws_account_id}"
  aws_assume_role_arn = "${var.aws_assume_role_arn}"
  slack_alert_sns_arn = "${module.eq-alerting.slack_alert_sns_arn}"
}

module "author-dynamodb" {
  source              = "./aws-dynamodb"
  env                 = "${var.env}-author"
  aws_account_id      = "${var.aws_account_id}"
  aws_assume_role_arn = "${var.aws_assume_role_arn}"
  slack_alert_sns_arn = "${module.eq-alerting.slack_alert_sns_arn}"
}

module "author-documentdb" {
  source                          = "./aws-documentdb"
  env                             = "${var.env}"
  aws_account_id                  = "${var.aws_account_id}"
  aws_assume_role_arn             = "${var.aws_assume_role_arn}"
  vpc_id                          = "${module.author-vpc.vpc_id}"
  documentdb_security_group_name  = "${var.env}-author-documentdb-security-group"
  documentdb_cluster_name         = "author-documentdb"
  documentdb_subnet_group_name    = "${module.author-vpc.database_subnet_group_name}"
  application_cidrs               = "${var.author_application_cidrs}"
  master_username                 = "${var.author_mongo_username}"
  master_password                 = "${var.author_mongo_password}"
}

module "author-redis" {
  source              = "./aws-redis"
  env                 = "${var.env}-author"
  aws_account_id      = "${var.aws_account_id}"
  aws_assume_role_arn = "${var.aws_assume_role_arn}"
  vpc_id              = "${module.author-vpc.vpc_id}"
  application_cidrs   = "${var.author_application_cidrs}"
  database_subnet_ids = "${module.author-vpc.database_subnet_ids}"
}

module "author-waf" {
  source              = "./aws-waf"
  env                 = "${var.env}-author"
  aws_account_id      = "${var.aws_account_id}"
  aws_assume_role_arn = "${var.aws_assume_role_arn}"
  external_alb_arn    = "${module.author-eq-ecs.aws_external_alb_arn}"
  metric_prefix       = "${var.env}Author"
}

output "author_service_address" {
  value = "${module.author.service_address}"
}
