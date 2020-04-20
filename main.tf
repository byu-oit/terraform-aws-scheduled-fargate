terraform {
  required_version = ">= 0.12.24"
  required_providers {
    aws = ">= 2.58"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  definitions = [var.primary_container_definition]
  ssm_parameters = distinct(flatten([
    for def in local.definitions :
    values(def.secrets != null ? def.secrets : {})
  ]))
  has_secrets            = length(local.ssm_parameters) > 0
  ssm_parameter_arn_base = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/"
  secrets_arns = [
    for param in local.ssm_parameters :
    "${local.ssm_parameter_arn_base}${replace(param, "/^//", "")}"
  ]

  cloudwatch_log_group_name = "scheduled-fargate/${var.app_name}" // CloudWatch Log Group name
  service_name              = var.app_name                        // ECS Service name

  container_definitions = [
    for def in local.definitions : {
      name       = def.name
      image      = def.image
      essential  = true
      privileged = false
      //      portMappings = [
      //        for port in def.ports :
      //        {
      //          containerPort = port
      //          hostPort      = port
      //          protocol      = "tcp"
      //        }
      //      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.cloudwatch_log_group_name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = local.service_name
        }
      }
      environment = [
        for key in keys(def.environment_variables != null ? def.environment_variables : {}) :
        {
          name  = key
          value = lookup(def.environment_variables, key)
        }
      ]
      secrets = [
        for key in keys(def.secrets != null ? def.secrets : {}) :
        {
          name      = key
          valueFrom = "${local.ssm_parameter_arn_base}${replace(lookup(def.secrets, key), "/^//", "")}"
        }
      ]
      mountPoints = []
      volumesFrom = []
    }
  ]
}

# ==================== Task Definition ====================
# --- task execution role ---
data "aws_iam_policy_document" "task_execution_policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      identifiers = [
      "ecs-tasks.amazonaws.com"]
      type = "Service"
    }
  }
}
resource "aws_iam_role" "task_execution_role" {
  name                 = "${var.app_name}-taskExecutionRole"
  assume_role_policy   = data.aws_iam_policy_document.task_execution_policy.json
  permissions_boundary = var.role_permissions_boundary_arn
  tags                 = var.tags
}
resource "aws_iam_role_policy_attachment" "task_execution_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.task_execution_role.name
}
// Make sure the fargate task has access to get the parameters from the container secrets
data "aws_iam_policy_document" "secrets_access" {
  count   = local.has_secrets ? 1 : 0
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters",
      "ssm:GetParameter",
      "ssm:GetParemetersByPath"
    ]
    resources = local.secrets_arns
  }
}
resource "aws_iam_policy" "secrets_access" {
  count  = local.has_secrets ? 1 : 0
  name   = "${var.app_name}_secrets_access"
  policy = data.aws_iam_policy_document.secrets_access[0].json
}
resource "aws_iam_role_policy_attachment" "secrets_policy_attach" {
  count      = local.has_secrets ? 1 : 0
  policy_arn = aws_iam_policy.secrets_access[0].arn
  role       = aws_iam_role.task_execution_role.name
}
# --- task role ---
data "aws_iam_policy_document" "task_policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      identifiers = [
      "ecs-tasks.amazonaws.com"]
      type = "Service"
    }
    actions = [
    "sts:AssumeRole"]
  }
}
resource "aws_iam_role" "task_role" {
  name                 = "${var.app_name}-taskRole"
  assume_role_policy   = data.aws_iam_policy_document.task_policy.json
  permissions_boundary = var.role_permissions_boundary_arn
  tags                 = var.tags
}
resource "aws_iam_role_policy_attachment" "task_policy_attach" {
  count      = length(var.task_policies)
  policy_arn = element(var.task_policies, count.index)
  role       = aws_iam_role.task_role.name
}
resource "aws_iam_role_policy_attachment" "secret_task_policy_attach" {
  count      = local.has_secrets ? 1 : 0
  policy_arn = aws_iam_policy.secrets_access[0].arn
  role       = aws_iam_role.task_role.name
}
# --- task definition ---
resource "aws_ecs_task_definition" "task_def" {
  container_definitions = jsonencode(local.container_definitions)
  family                = "${var.app_name}-def"
  cpu                   = var.task_cpu
  memory                = var.task_memory
  network_mode          = "awsvpc"
  requires_compatibilities = [
  "FARGATE"]
  execution_role_arn = aws_iam_role.task_execution_role.arn
  task_role_arn      = aws_iam_role.task_role.arn

  tags = var.tags
}
