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
| schedule_expression | string | The scheduling expression. For example, cron(0 20 * * ? *) or rate(5 minutes). See [AWS Docs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html) | |
| primary_container_definition | [object](#container_definition) | The primary container definition for your application | |
| task_cpu | number | CPU for the task definition | 256 |
| task_memory | number | Memory for the task definition | 512 |
| task_policies | list(string) | List of IAM Policy ARNs to attach to the task execution IAM Policy| [] |
| security_groups | list(string) | List of extra security group IDs to attach to the fargate task | []|
| ecs_cluster_arn | string | ECS Cluster to place scheduled fargate task(s). If null is provided, this module creates its own ECS cluster | null |
| event_role_arn | string | IAM Role ARN to attach to CloudWatch Event Rule (typically PowerBuilder) | |
| vpc_id | string | VPC ID to deploy the ECS fargate service and ALB | |
| private_subnet_ids | list(string) | List of subnet IDs for the fargate service | |
| role_permissions_boundary_arn | string | ARN of the IAM Role permissions boundary to place on each IAM role created | |
| tags | map(string) | A map of AWS Tags to attach to each resource created | {} |

#### container_definition
Object with following attributes to define the docker container(s) your fargate needs to run.
* **`name`** - (Required) container name (referenced in CloudWatch logs, and possibly by other containers)
* **`image`** - (Required) the ecr_image_url with the tag like: `<acct_num>.dkr.ecr.us-west-2.amazonaws.com/myapp:dev` or the image URL from dockerHub or some other docker registry
* **`environment_variables`** - (Required) a map of environment variables to pass to the docker container
* **`secrets`** - (Required) a map of secrets from the parameter store to be assigned to env variables

## Outputs
| Name | Type | Description |
| ---  | ---  | --- |
| ecs_cluster | [object](https://www.terraform.io/docs/providers/aws/r/ecs_cluster.html#attributes-reference) | If you didn't provide your own ECS Cluster, this output is the ECS Cluster object that this module created |
| fargate_security_group | [object](https://www.terraform.io/docs/providers/aws/r/security_group.html#attributes-reference) | Security Group object assigned to the scheduled Fargate task |
| task_definition | [object](https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html#attributes-reference) | The task definition object of the scheduled fargate task |
| event_rule | [object](https://www.terraform.io/docs/providers/aws/r/cloudwatch_event_rule.html#attributes-reference) | The CloudWatch Event Rule |
| event_target | [object](https://www.terraform.io/docs/providers/aws/r/cloudwatch_event_target.html#attributes-reference) | The CloudWatch Event Target |
| log_group | [object](https://www.terraform.io/docs/providers/aws/r/cloudwatch_log_group.html#attributes-reference) | The CloudWatch Log Group for the scheduled fargate task |

