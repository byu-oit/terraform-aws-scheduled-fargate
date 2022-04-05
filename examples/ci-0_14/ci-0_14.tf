terraform {
  required_version = "0.14.8"
}

provider "aws" {
  version = ">= 3.0"
  region  = "us-west-2"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v3.4.1"
}

module "scheduled_fargate" {
  source = "../../"

  app_name            = "test-scheduled-fargate-dev"
  schedule_expression = "rate(5 minutes)"
  primary_container_definition = {
    name                  = "test"
    image                 = "hello-world"
    command               = null
    environment_variables = {}
    secrets               = {}
    efs_volume_mounts     = null
  }
  event_role_arn                = module.acs.power_builder_role.arn
  vpc_id                        = module.acs.vpc.id
  private_subnet_ids            = module.acs.private_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn

  tags = {
    app = "testing-scheduled-fargate"
  }
}


output "scheduled_fargate_ecs_cluster" {
  value = module.scheduled_fargate.ecs_cluster
}

output "scheduled_fargate_security_group" {
  value = module.scheduled_fargate.fargate_security_group
}

output "scheduled_task_definition" {
  value = module.scheduled_fargate.task_definition
}

output "scheduled_event_rule" {
  value = module.scheduled_fargate.event_rule
}

output "scheduled_event_target" {
  value = module.scheduled_fargate.event_target
}

output "scheduled_log_group" {
  value = module.scheduled_fargate.log_group
}

output "task_execution_role" {
  value = module.scheduled_fargate.task_execution_role
}

output "task_role" {
  value = module.scheduled_fargate.task_role
}
