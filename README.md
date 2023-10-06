![Latest GitHub Release](https://img.shields.io/github/v/release/byu-oit/terraform-aws-scheduled-fargate?sort=semver)

# Terraform AWS Scheduled Topic
Creates a scheduled Fargate Task in AWS

#### [New to Terraform Modules at BYU?](https://github.com/byu-oit/terraform-documentation)

## Usage
```hcl
module "test_scheduled_task" {
   source = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v4.0.0"

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
}
```

## Migration to v4
V4 has a significant amount of breaking changes from v3 and earlier:

* How we use an existing ECS cluster allowing the creating of a cluster alongside using it as an existing cluster in the same terraform configuration.
* This module now uses the [EventBridge Scheduler](https://docs.aws.amazon.com/eventbridge/latest/userguide/scheduler.html) instead of CloudWatch EventBridge Rules.

[**View the migration how-to-guide**](docs/migration-to-v4.md)

## Requirements
* Terraform version 1.3 or greater
* AWS provider version 4.0 or greater

## Inputs
| Name                          | Type                            | Description                                                                                                                                                                    | Default                       |
|-------------------------------|---------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------|
| app_name                      | string                          | Application name to name your scheduled Fargate task and other resources                                                                                                       |                               |
| existing_ecs_cluster          | [object](#existing_ecs_cluster) | Existing ECS Cluster configuration to host the fargate scheduled task. Defaults to creating its own cluster.                                                                   |                               |
| schedule                      | [object](#schedule)             | Configuration to run this fargate task on a schedule                                                                                                                           |                               |
| event                         | [object](#event)                | Configuration to run this fargate task triggered by an event                                                                                                                   |                               |
| primary_container_definition  | [object](#container_definition) | The primary container definition for your application                                                                                                                          |                               |
| task_cpu                      | number                          | CPU for the task definition                                                                                                                                                    | 256                           |
| task_memory                   | number                          | Memory for the task definition                                                                                                                                                 | 512                           |
| cpu_architecture              | string                          | CPU architecture for the task definition. See [docs](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#runtime-platform) for options | "X86_64"                      |
| task_policies                 | list(string)                    | List of IAM Policy ARNs to attach to the task execution IAM Policy                                                                                                             | []                            |
| security_groups               | list(string)                    | List of extra security group IDs to attach to the fargate task                                                                                                                 | []                            |
| log_retention_in_days         | number                          | The number of days to keep logs in CloudWatch Log Group. Possible values are: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, and 3653.                   | 7                             |
| log_group_name                | string                          | The Cloudwatch Log Group name                                                                                                                                                  | scheduled-fargate/${app_name} |
| vpc_id                        | string                          | VPC ID to deploy the ECS fargate service and ALB                                                                                                                               |                               |
| private_subnet_ids            | list(string)                    | List of subnet IDs for the fargate service                                                                                                                                     |                               |
| role_permissions_boundary_arn | string                          | ARN of the IAM Role permissions boundary to place on each IAM role created                                                                                                     |                               |
| tags                          | map(string)                     | A map of AWS Tags to attach to each resource created                                                                                                                           | {}                            |

#### existing_ecs_cluster
Object with following attributes to define an existing ECS cluster to deploy the fargate tasks.
* **`arn`** - (Required) string of the ARN of the existing ECS cluster

If you want to deploy this scheduled fargate task onto an existing cluster you would need to define this variable. For example:
```hcl
module "test_scheduled_task" {
  source = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v4.0.0"

  app_name             = "test-scheduled-fargate-dev"
  existing_ecs_cluster = {
    arn = module.my_fargate_api.ecs_cluster.arn
  }
  schedule_expression          = "rate(5 minutes)"
  // ...
}
```

#### schedule
Object with configuration needed to run this fargate task on a schedule
* **`expression`** - (Required) When to execute this fargate task. Use 'cron()', 'rate()', or 'at()'.
* **`timezone`** - Timezone for the scheduled expression. Defaults to America/Denver.
* **`start_date`** - The timestamp (ISO format UTC time zone), after which the scheduled task will begin following the schedule_expression. If null or not provided, then this schedule is effective immediately. Defaults to null.
* **`end_date`** - The timestamp (ISO format UTC time zone) when the scheduled task will stop being invoked. If null or not provided, then this schedule is effective forever. Defaults to null.
* **`group_name`** - Existing EventBridge Scheduler Schedule Group name to group related scheduled tasks in the CloudWatch Scheduler. Defaults to the default group in every AWS account.

#### event
Object with configuration needed to run this fargate task triggered by an event
* **`pattern`** - (Required) The event pattern described as a JSON object.

#### container_definition
Object with following attributes to define the docker container(s) your fargate needs to run.
* **`name`** - (Required) container name (referenced in CloudWatch logs, and possibly by other containers)
* **`image`** - (Required) the ecr_image_url with the tag like: `<acct_num>.dkr.ecr.us-west-2.amazonaws.com/myapp:dev` or the image URL from dockerHub or some other docker registry
* **`entryPoint`** the [entrypoint](https://docs.docker.com/engine/reference/run/#entrypoint-default-command-to-execute-at-runtime) to run the docker container with. Can omit or set to `null` to use the default container command.
* **`command`** - the [command](https://docs.docker.com/engine/reference/run/#cmd-default-command-or-options) to run the docker container with. Can omit or set to `null` to use the default container command.
* **`environment_variables`** - a map of environment variables to pass to the docker container
* **`secrets`** - a map of secrets from the parameter store to be assigned to env variables
* **`efs_volume_mounts`** - a list of efs_volume_mount [objects](#efs_volume_mount) to be mounted into the container.

**Before running this configuration** make sure that your ECR repo exists and an image has been pushed to the repo.

#### efs_volume_mount
Example
```
    efs_volume_mounts = [
      {
        name = "persistent_data"
        file_system_id = aws_efs_file_system.my_efs.id
        root_directory = "/"
        container_path = "/usr/app/data"
      }
    ]
```
* **`name`** - A logical name used to describe what the mount is for.
* **`file_system_id`** - ID of the EFS to mount.
* **`root_directory`** - Source path inside the EFS.
* **`container_path`** - Target path inside the container.

See the following docs for more details:
* https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html#volume-block-arguments
* https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html#efs-volume-configuration-arguments
* https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDefinition.html
* https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_MountPoint.html

## Examples 
[complex-example](examples/complex)

* Uses existing ECR repo
* Connects to DynamoDB table
* Mounts EFS volume

[event-triggered-example](examples/event/triggered-by-event.tf)

* Creates an S3 bucket and this module
* Triggers a fargate task off of uploading an object to the S3 bucket

## Outputs
| Name                   | Type                                                                                                                | Description                                                                                                                                       |
|------------------------|---------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| new_ecs_cluster        | [object](https://www.terraform.io/docs/providers/aws/r/ecs_cluster.html#attributes-reference)                       | Newly created ECS Cluster the scheduled task is deployed on, if var.existing_ecs_cluster is provided this will return null                        |
| fargate_security_group | [object](https://www.terraform.io/docs/providers/aws/r/security_group.html#attributes-reference)                    | Security Group object assigned to the scheduled Fargate task                                                                                      |
| task_definition        | [object](https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html#attributes-reference)               | The task definition object of the scheduled fargate task                                                                                          |
| schedule               | [object](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule)            | The CloudWatch EventBridge Scheduler Schedule. (will be null if only event_pattern was provided)                                                  |
| event_rule             | [object](https://www.terraform.io/docs/providers/aws/r/cloudwatch_event_rule.html#attributes-reference)             | The CloudWatch Event Rule. (will be null if only event_schedule was provided)                                                                     |
| event_target           | [object](https://www.terraform.io/docs/providers/aws/r/cloudwatch_event_target.html#attributes-reference)           | The CloudWatch Event Target. (will be null if only event_schedule was provided)                                                                   |
| log_group              | [object](https://www.terraform.io/docs/providers/aws/r/cloudwatch_log_group.html#attributes-reference)              | The CloudWatch Log Group for the scheduled fargate task                                                                                           |
| task_execution_role    | [object](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role#attributes-reference) | The IAM role assigned to launch the Fargate task                                                                                                  |
| task_role              | [object](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role#attributes-reference) | The IAM role assigned to the scheduled Fargate task                                                                                               |
| run_task_cli_command   | string                                                                                                              | A generated AWS CLI command to run the task manually. (Marked as sensitive so use `terraform output -raw run_task_cli_command` to get the value)  |

## To Run Scheduled Fargate Task Manually
Sometimes it is desired to run the scheduled fargate task outside its schedule.
You can run the task manually by running the task definition via the CLI or in the Console.
This allows for testing your scheduled fargate without having to wait for the appointed scheduled time.

### Run Task Via CLI

1. Make sure you're logged into the AWS account via `aws sso login`
2. Copy the raw value of the `run_task_cli_command`
   ```sh
   aws output -raw run_task_cli_command
   ```
3. Run the output. It'll look something like:
   ```sh
   aws ecs run-task \
     --task-definition <TASK_DEFINITION> \
     --cluster <ECS_CLUSTER> \
     --network-configuration "{\"awsvpcConfiguration\":{\"subnets\":[\"<subnet-SUBNET_ID>\"],\"securityGroups\":[\"<sg-SECURITY_GROUP_ID>\"]}}" \
     --launch-type FARGATE \
     --propagate-tags TASK_DEFINITION
   ```

Or you can log into the AWS console and look at the scheduled task in the ECS console to get all the values you need. 

* `<TASK_DEFINITION>`: the task definition name
* `<ECS_CLUSTER>`: the cluster the scheduled fargate normally runs on
* `<SUBNET_ID>`: needs to be one of the same subnets it normally runs on
* `<SECURITY_GROUP_ID>`: the EC2 security group the scheduled fargate is assigned

**Note:** the `--propagate-tags TASK_DEFINITION` is the actual string, don't replace `TASK_DEFINITION` with the task definition name

### Run Task Via AWS Console
1. Log into the AWS account
2. Go to ECS service
3. Find the Task Definition of the Scheduled Fargate taks
4. Click "Run Task" under the "Actions" dropdown
5. Fill out the form
   1. Launch Type: `FARGATE`
   2. Cluster: needs to be the same cluster the scheduled fargate runs one normally
   3. Cluster VPC: needs to be the same VPC it normally runs on
   4. Subnets: needs to be one of the same subnets it normally runs on
   5. Propagate tags from: `Task definitions`
6. Click "Run Task"
