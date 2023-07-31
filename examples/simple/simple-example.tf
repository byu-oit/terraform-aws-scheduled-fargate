terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.69"
    }
  }
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v3.5.0"
}

module "scheduled_fargate" {
  #  source              = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v4.0.0"
  source              = "../../"
  app_name            = "scheduled-fargate-simple-example-dev"
  schedule_expression = "rate(5 minutes)"
  primary_container_definition = {
    name  = "test"
    image = "hello-world"
  }
  event_role_arn                = module.acs.power_builder_role.arn
  vpc_id                        = module.acs.vpc.id
  private_subnet_ids            = module.acs.private_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn

  tags = {
    app = "testing-scheduled-fargate"
  }
}
