# eq-author-terraform

Terraform project that creates the infrastructure for EQ Author.

## Setting up your AWS credentials

1. Ensure you have been set up with an AWS account

1. Obtain your AWS credentials - http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-set-up.html#cli-signup

1. And configure them - http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html


## Setting up Terraform

1. Install [Terraform Version Manager](https://github.com/kamatama41/tfenv) - `brew install tfenv`

1. Install [Terraform](https://terraform.io) - `tfenv install`

1. Copy `terraform.tfvars.example` to `terraform.tfvars`. 

```
env="" # your name (Do not use underscore)

# ask somebody on the team to send these values to you
aws_account_id=""
aws_assume_role_arn=""
ons_access_ips=""
certificate_arn=""
slack_webhook_path=""

# Create your own credentials here https://firebase.google.com/
author_firebase_project_id=""
author_firebase_api_key=""

# A service account is required to verify Firebase tokens in Author's API.
# A key file can be generated for the service account by following the instructions at https://firebase.google.com/docs/admin/setup#initialize_the_sdk
# The following variable needs to be set and should be a path to the JSON key file.
author_firebase_service_account_key=""

#The key file can be synced from an S3 bucket by setting the following variable
author_secrets_bucket_name=""

# See also https://github.com/ONSdigital/eq-author-app/blob/master/docs/AUTHENTICATION.md


```

1. Run `aws configure`. Add your AWS access key and secret key when prompted for S3. Use "eu-west-1" as your region name. Leave any other values as default.

## Running Terraform

  - Run `terraform init` to import the different modules and set up remote state. When asked to provide a name for the state file choose the same name as the `env` value in your `terraform.tfvars`

  - Run `terraform plan` to check the output of terraform

  - Run `terraform apply` to create your infrastructure environment

  - Run `terraform destroy` to destroy your infrastructure environment

## Updating infrastructure with new config

After making changes to your terraform config you can update your environment rather than destroying and recreating:

  - Run `terraform get --update` to import the updated modules to your local .terraform dir

  - Run `terraform plan` to check the output of terraform

  - Run `terraform apply` to apply the changes to your infrastructure environment

## Alerting

A webhook will need to be created for a new integration via https://api.slack.com/incoming-webhooks. Alternatively, your team may already have a webhook url configured to send messages to your slack.

Create a slack channel with the name `eq-<your-env-name>-alerts`, for example `eq-preprod-alerts`


## Author VPC
cidr_block = `10.0.0.0/16`

| Subnet | CIDR | Size |
| --- | --- | --- |
| ENV-public-subnet-1 | `10.0.0.0/24` | 256 |
| ENV-public-subnet-2 | `10.0.1.0/24` | 256 |
| ENV-public-subnet-3 | `10.0.2.0/24` | 256 |
| ENV-database-subnet-1 | `10.0.3.0/24` | 256 |
| ENV-database-subnet-2 | `10.0.4.0/24` | 256 |
| ENV-database-subnet-3 | `10.0.5.0/24` | 256 |
| ENV-application-subnet-1 | `10.0.64.0/18` | 16384 |
| ENV-application-subnet-2 | `10.0.128.0/18` | 16384 |
| ENV-application-subnet-3 | `10.0.192.0/18` | 16384 |