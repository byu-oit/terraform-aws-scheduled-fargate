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

  container_definitions = [
    for def in local.definitions : {
      name       = def.name
      image      = def.image
      essential  = true
      privileged = false
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.cloudwatch_log_group_name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = var.app_name
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
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
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
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
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
  container_definitions    = jsonencode(local.container_definitions)
  family                   = "${var.app_name}-def"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  tags = var.tags
}

# ==================== Fargate ====================
resource "aws_ecs_cluster" "cluster" {
  count = var.ecs_cluster_arn == null ? 1 : 0
  name  = var.app_name
  tags  = var.tags
}
resource "aws_security_group" "fargate_service_sg" {
  name        = "${var.app_name}-fargate-sg"
  description = "Controls access to the Fargate Service"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

# ==================== Cloudwatch Event ====================
# --- CloudWatch Event IAM Role ---
data "aws_iam_policy_document" "cloudwatch-event-assume-role-policy" {
  version = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["events.amazonaws.com"]
      type        = "Service"
    }
  }
}
resource "aws_iam_role" "scheduled-task-cloudwatch" {
  name                 = "${var.app_name}-scheduled-task-cloudwatch"
  assume_role_policy   = data.aws_iam_policy_document.cloudwatch-event-assume-role-policy.json
  permissions_boundary = var.role_permissions_boundary_arn
  tags                 = var.tags
}
data "aws_iam_policy_document" "cloudwatch-event-policy" {
  version = "2012-10-17"
  statement {
    effect    = "Allow"
    actions   = ["ecs:runTask"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.task_execution_role.arn, aws_iam_role.task_role.arn]
  }
}
resource "aws_iam_policy" "cloudwatch-policy" {
  name   = "${var.app_name}-event-policy"
  policy = data.aws_iam_policy_document.cloudwatch-event-policy.json
}
resource "aws_iam_role_policy_attachment" "cloudwatch-event-role-policy-attach" {
  policy_arn = aws_iam_policy.cloudwatch-policy.arn
  role       = aws_iam_role.scheduled-task-cloudwatch.name
}
# --- CloudWatch Event Rule ---
resource "aws_cloudwatch_event_rule" "scheduled_task" {
  name                = "${var.app_name}-scheduled-task"
  description         = "Run ${var.app_name} task at a scheduled time (${var.schedule_expression})"
  schedule_expression = var.schedule_expression
}
resource "aws_cloudwatch_event_target" "scheduled_task" {
  target_id = "${var.app_name}-scheduled-task-target"
  rule      = aws_cloudwatch_event_rule.scheduled_task.name
  arn       = var.ecs_cluster_arn == null ? aws_ecs_cluster.cluster[0].arn : var.ecs_cluster_arn
//  role_arn  = aws_iam_role.scheduled-task-cloudwatch.arn # TODO see if we can use this role instead of PowerBuilder
  role_arn = var.event_role_arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.task_def.arn
    launch_type         = "FARGATE"
    platform_version    = "LATEST"
    network_configuration {
      security_groups = [aws_security_group.fargate_service_sg.id]
      subnets         = var.private_subnet_ids
    }
  }
}

# ==================== CloudWatch ====================
resource "aws_cloudwatch_log_group" "container_log_group" {
  name              = local.cloudwatch_log_group_name
  retention_in_days = 7
  tags              = var.tags
}
