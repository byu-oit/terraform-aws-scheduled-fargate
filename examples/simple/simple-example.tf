provider "aws" {
  version = "~> 2.42"
  region  = "us-west-2"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v2.1.0"
}

variable "env" {
  type = string
}

locals {
  name = "scheduled-fargate-db-example"
  tags = {
    env              = "${var.env}"
    data-sensitivity = "public"
    repo             = "https://github.com/byu-oit/${local.name}"
  }
}

module "scheduled_fargate" {
//    source = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v0.1.0"
  source = "../../" # for local testing during module development

  app_name            = "test-scheduled-fargate-dev"
  schedule_expression = "rate(5 minutes)"
  primary_container_definition = {
    name                  = "test"
    image                 = "hello-world"
    environment_variables = {}
    secrets               = {}
  }
  event_role_arn                = module.acs.power_builder_role.arn
  vpc_id                        = module.acs.vpc.id
  private_subnet_ids            = module.acs.private_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn

  environment_variables = {
    DYNAMO_TABLE_NAME = aws_dynamodb_table.my_dynamo_table.name,
    BUCKET_NAME = aws_s3_bucket.my_s3_bucket.bucket
  }
  
  tags = {
    app = "testing-scheduled-fargate"
  }
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
