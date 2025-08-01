terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}


module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v4.0.0"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "image_tag" {
  type = string
}

locals {
  name = "scheduled-fargate-complex-example-dev"
  tags = {
    env              = var.env
    data-sensitivity = "public"
    repo             = "https://github.com/byu-oit/${local.name}"
  }
}

resource "aws_ecs_cluster" "existing" {
  name = "test-existing-cluster"
}
resource "aws_ecr_repository" "repo" {
  name = "test-existing-ecr"
}
output "repo_url" {
  // use this to push docker image
  value = aws_ecr_repository.repo.repository_url
}

resource "aws_scheduler_schedule_group" "group" {
  name = "test"
}

// Scheduled fargate
module "scheduled_fargate" {
  #  source              = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v4.1.0"
  source   = "../../"
  app_name = local.name
  existing_ecs_cluster = {
    arn = aws_ecs_cluster.existing.arn
  }
  schedule = {
    expression = "rate(5 minutes)"
    timezone   = "UTC"
    start_date = "2023-10-01T00:00:00.000Z"
    end_date   = "2023-10-02T00:00:00.000Z"
  }

  log_group_name = aws_scheduler_schedule_group.group.name
  primary_container_definition = {
    name  = "test-dynamo"
    image = "${aws_ecr_repository.repo.repository_url}:${var.image_tag}"
    environment_variables = {
      DYNAMO_TABLE_NAME = aws_dynamodb_table.my_dynamo_table.name
    }
    efs_volume_mounts = [
      {
        name           = "persistent_data"
        file_system_id = aws_efs_file_system.my_efs.id
        root_directory = "/"
        container_path = "/usr/app/data"
      }
    ]
  }
  task_policies                 = [aws_iam_policy.my_dynamo_policy.arn]
  vpc_id                        = module.acs.vpc.id
  private_subnet_ids            = module.acs.private_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn

  tags = local.tags
}

// Dynamo DB table and wiring to allow fargate to talk to dynamo
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

// EFS and wiring up to make sure fargate can talk to EFS
resource "aws_efs_file_system" "my_efs" {}

resource "aws_security_group" "efs_sg" {
  name        = "${local.name}-efs"
  description = "EFS Mount for ${local.name}"
  vpc_id      = module.acs.vpc.id

  ingress {
    protocol        = "tcp"
    from_port       = 2049
    to_port         = 2049
    security_groups = [module.scheduled_fargate.fargate_security_group.id]
  }
}

resource "aws_efs_mount_target" "efs_target" {
  for_each = nonsensitive(toset(module.acs.private_subnet_ids))

  file_system_id  = aws_efs_file_system.my_efs.id
  subnet_id       = each.key
  security_groups = [aws_security_group.efs_sg.id]
}
