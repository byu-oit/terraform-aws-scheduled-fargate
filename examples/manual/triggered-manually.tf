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
  #  source              = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v4.0.0"
  source   = "../../"
  app_name = "triggered-manually-example-dev"
  primary_container_definition = {
    name  = "test"
    image = "hello-world"
  }
  vpc_id                        = module.acs.vpc.id
  private_subnet_ids            = module.acs.private_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
}

output "run_task_cli_command" {
  value     = module.scheduled_fargate.run_task_cli_command
  sensitive = true
}
