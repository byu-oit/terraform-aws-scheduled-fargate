variable "app_name" {
  type        = string
  description = "Scheduled Fargate Application name."
}
variable "primary_container_definition" {
  type = object({
    name  = string
    image = string
    //    ports                 = list(number)
    environment_variables = map(string)
    secrets               = map(string)
  })
  description = "The primary container definition for your application. This one will be the only container that receives traffic from the ALB, so make sure the 'ports' field contains the same port as the 'image_port'"
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

variable "role_permissions_boundary_arn" {
  type        = string
  description = "IAM Role Permissions Boundary ARN"
}

variable "tags" {
  type        = map(string)
  description = "AWS Tags to attach to AWS resources"

  default = {}
}
