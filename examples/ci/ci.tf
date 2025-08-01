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

module "scheduled_fargate" {
  #  source              = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v4.1.0"
  source   = "../../"
  app_name = "test-scheduled-fargate-dev"
  schedule = {
    expression = "rate(5 minutes)"
  }
  primary_container_definition = {
    name  = "test"
    image = "hello-world"
  }
  vpc_id                        = module.acs.vpc.id
  private_subnet_ids            = module.acs.private_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn

  tags = {
    app = "testing-scheduled-fargate"
  }
}

output "scheduled_fargate_new_ecs_cluster" {
  value = module.scheduled_fargate.new_ecs_cluster
}

output "scheduled_fargate_security_group" {
  value = module.scheduled_fargate.fargate_security_group
}

output "scheduled_task_definition" {
  value = module.scheduled_fargate.task_definition
}

output "schedule" {
  value     = module.scheduled_fargate.schedule
  sensitive = true
}

output "scheduled_log_group" {
  value = module.scheduled_fargate.log_group
}

output "task_execution_role" {
  value     = module.scheduled_fargate.task_execution_role
  sensitive = true
}

output "task_role" {
  value     = module.scheduled_fargate.task_role
  sensitive = true
}

output "run_task_cli_command" {
  value     = module.scheduled_fargate.run_task_cli_command
  sensitive = true
}
