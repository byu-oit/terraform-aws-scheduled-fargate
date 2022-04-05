variable "app_name" {
  type        = string
  description = "Scheduled Fargate Application name."
}
variable "ecs_cluster_name" {
  type        = string
  description = "ECS Cluster name to host the scheduled fargate task. Defaults to creating its own cluster."
  default     = null
}
variable "schedule_expression" {
  type        = string
  description = "When to execute this fargate task. Use 'cron()' or 'rate()' At least one of schedule_expression or event_pattern is required."
  default     = null
}
variable "event_pattern" {
  type        = string
  description = "The event pattern described a JSON object. At least one of schedule_expression or event_pattern is required."
  default     = null
}
variable "primary_container_definition" {
  type = object({
    name    = string
    image   = string
    command = list(string)
    //    ports                 = list(number)
    environment_variables = map(string)
    secrets               = map(string)
    efs_volume_mounts = list(object({
      name           = string
      file_system_id = string
      root_directory = string
      container_path = string
    }))
  })
  description = "The primary container definition for your application."
}
variable "task_cpu" {
  type        = number
  description = "CPU for the task definition. Defaults to 256."
  default     = 256
}
variable "task_memory" {
  type        = number
  description = "Memory for the task definition. Defaults to 512."
  default     = 512
}
variable "task_policies" {
  type        = list(string)
  description = "List of IAM Policy ARNs to attach to the task execution policy."
  default     = []
}
variable "security_groups" {
  type        = list(string)
  description = "List of extra security group IDs to attach to the fargate task."
  default     = []
}
variable "log_retention_in_days" {
  type        = number
  description = "The number of days to keep logs in CloudWatch Log Group. Defaults to 7."
  default     = 7
}
// AWS account config variables
variable "event_role_arn" {
  type        = string
  description = "IAM Role ARN to attach to CloudWatch Event Rule (typically PowerBuilder)"
}
variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy ECS fargate service."
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "role_permissions_boundary_arn" {
  type        = string
  description = "IAM Role Permissions Boundary ARN"
}

variable "tags" {
  type        = map(string)
  description = "AWS Tags to attach to AWS resources"

  default = {}
}
