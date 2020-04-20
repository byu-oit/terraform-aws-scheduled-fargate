![Latest GitHub Release](https://img.shields.io/github/v/release/byu-oit/terraform-aws-scheduled-fargate?sort=semver)

# Terraform AWS Scheduled Topic
Creates a scheduled Fargate Task in AWS

#### [New to Terraform Modules at BYU?](https://github.com/byu-oit/terraform-documentation)

## Usage
```hcl
module "test_scheduled_task" {
  source = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v0.1.0"

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

  tags = {
    app = "testing-scheduled-fargate"
  }
}
```

## Requirements
* Terraform version 0.12.24 or greater
* AWS provider version 2.58 or greater

## Inputs
| Name | Type  | Description | Default |
| --- | --- | --- | --- |
| app_name | string | Application name to name your scheduled Fargate task and other resources | |
| schedule_expression | string | When to execute this fargate task. Use 'cron()' or 'rate()' | |
| primary_container_definition | [object](#container_definition) | The primary container definition for your application. This one will be the only container that receives traffic from the ALB, so make sure the `ports` field contains the same port as the `image_port` | |
| task_cpu | number | CPU for the task definition | 256 |
| task_memory | number | Memory for the task definition | 512 |
| task_policies | list(string) | List of IAM Policy ARNs to attach to the task execution IAM Policy| [] |
| ecs_cluster_arn | string | | | |
| event_role_arn | string | | | |
| vpc_id | string | VPC ID to deploy the ECS fargate service and ALB | |
| private_subnet_ids | list(string) | List of subnet IDs for the fargate service | |
| role_permissions_boundary_arn | string | ARN of the IAM Role permissions boundary to place on each IAM role created | |
| tags | map(string) | A map of AWS Tags to attach to each resource created | {} |

## Outputs
| Name | Type | Description |
| ---  | ---  | --- |
| | | |
