provider "aws" {
  version = "~> 2.42"
  region  = "us-west-2"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v2.1.0"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "image_tag" {
  type = string
}

locals {
  name = "scheduled-fargate-db-example"
  tags = {
    env              = var.env
    data-sensitivity = "public"
    repo             = "https://github.com/byu-oit/${local.name}"
  }
}

module "ecr" {
  source = "github.com/byu-oit/terraform-aws-ecr?ref=v1.1.0"
  name   = "${local.name}-${var.env}"
}

module "scheduled_fargate" {
  source = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v.1.0.0"
  // source = "../../" # for local testing during module development

  app_name            = "scheduled-fargate-db-example-${var.env}"
  schedule_expression = "rate(5 minutes)"
  primary_container_definition = {
    name  = "test-dynamo"
    image = "${module.ecr.repository.repository_url}:${var.image_tag}"
    environment_variables = {
      DYNAMO_TABLE_NAME = aws_dynamodb_table.my_dynamo_table.name
    }
    secrets           = {}
    efs_volume_mounts = null
  }
  task_policies                 = [aws_iam_policy.my_dynamo_policy.arn]
  event_role_arn                = module.acs.power_builder_role.arn
  vpc_id                        = module.acs.vpc.id
  private_subnet_ids            = module.acs.private_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn

  tags = local.tags
}

resource "aws_dynamodb_table" "my_dynamo_table" {
  name         = "${local.name}-${var.env}"
  hash_key     = "my_key_field"
  billing_mode = "PAY_PER_REQUEST"
  tags         = local.tags
  attribute {
    name = "my_key_field"
    type = "S"
  }
}

resource "aws_iam_policy" "my_dynamo_policy" {
  name        = "${local.name}-dynamo-${var.env}"
  path        = "/"
  description = "Access to dynamo table"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGet*",
                "dynamodb:DescribeStream",
                "dynamodb:DescribeTable",
                "dynamodb:Get*",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:BatchWrite*",
                "dynamodb:Update*",
                "dynamodb:PutItem"
            ],
            "Resource": "${aws_dynamodb_table.my_dynamo_table.arn}"
        }
    ]
}
EOF
}
