provider "aws" {
  version = "~> 2.42"
  region  = "us-west-2"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v2.0.0"
}

module "scheduled_fargate" {
//  source = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v1.0.0"
  source = "../" # for local testing during module development

  app_name = "test"
  primary_container_definition = {
    name = "test"
    image = "hello-world"
    environment_variables = {}
    secrets = {}
  }
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn

  tags = {
    app = "testing-scheduled-fargate"
  }
}
