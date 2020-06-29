provider "aws" {
  version = "~> 2.42"
  region  = "us-west-2"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v2.1.0"
}

resource "aws_ecs_cluster" "existing" {
  name = "test-existing"
}

module "scheduled_fargate" {
  //  source = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v.1.0.0"
  source = "../../" # for local testing during module development

  app_name            = "test-scheduled-fargate-dev"
  ecs_cluster_name    = aws_ecs_cluster.existing.name
  schedule_expression = "rate(5 minutes)"
  primary_container_definition = {
    name                  = "test"
    image                 = "hello-world"
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
