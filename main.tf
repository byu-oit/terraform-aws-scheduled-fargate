terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = ">= 4.0"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  use_scheduler      = var.schedule != null
  use_event_rule     = var.event != null
  create_new_cluster = var.existing_ecs_cluster == null
  definitions        = [var.primary_container_definition]
  volumes = distinct(flatten([
    for def in local.definitions :
    def.efs_volume_mounts != null ? def.efs_volume_mounts : []
  ]))
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

  cloudwatch_log_group_name = length(var.log_group_name) > 0 ? var.log_group_name : "scheduled-fargate/${var.app_name}" // CloudWatch Log Group name

  container_definitions = [
    for def in local.definitions : {
      name       = def.name
      image      = def.image
      entryPoint = def.entry_point
      command    = def.command
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
      mountPoints = [
        for mount in(def.efs_volume_mounts != null ? def.efs_volume_mounts : []) :
        {
          containerPath = mount.container_path
          sourceVolume  = mount.name
          readOnly      = false
        }
      ]
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
  name                 = "${var.app_name}-task-execution-role"
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
      "ssm:GetParametersByPath"
    ]
    resources = local.secrets_arns
  }
}
resource "aws_iam_policy" "secrets_access" {
  count  = local.has_secrets ? 1 : 0
  name   = "${var.app_name}-secrets-access"
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
  name                 = "${var.app_name}-task-role"
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
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  dynamic "volume" {
    for_each = local.volumes
    content {
      name = volume.value.name
      efs_volume_configuration {
        file_system_id = volume.value.file_system_id
        root_directory = volume.value.root_directory
      }
    }
  }

  tags = var.tags
}

# ==================== Fargate ====================
resource "aws_ecs_cluster" "new_cluster" {
  count = local.create_new_cluster ? 1 : 0 # if custer is not provided create one
  name  = var.app_name
  tags  = var.tags
}
resource "aws_security_group" "fargate_sg" {
  name        = "${var.app_name}-fargate-sg"
  description = "Controls access to the ${var.app_name} scheduled Fargate task"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

# ==================== Cloudwatch EventBridge ====================
# --- IAM Policy to assume role ---
data "aws_iam_policy_document" "assume_role_policy" {
  count   = local.use_scheduler || local.use_event_rule ? 1 : 0
  version = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = compact([
        local.use_scheduler ? "scheduler.amazonaws.com" : null,
        local.use_event_rule ? "events.amazonaws.com" : null
      ])
      type = "Service"
    }
  }
}

# --- IAM Role to be able to run the task ---
resource "aws_iam_role" "trigger" {
  count                = local.use_scheduler || local.use_event_rule ? 1 : 0
  name                 = "${var.app_name}-trigger"
  assume_role_policy   = data.aws_iam_policy_document.assume_role_policy[0].json
  permissions_boundary = var.role_permissions_boundary_arn
  tags                 = var.tags
}
data "aws_iam_policy_document" "run_task_policy" {
  count   = local.use_scheduler || local.use_event_rule ? 1 : 0
  version = "2012-10-17"
  statement {
    # Allow the Cloudwatch Event Rule and/or Scheduler to run the ECS task
    effect    = "Allow"
    actions   = ["ecs:runTask"]
    resources = [aws_ecs_task_definition.task_def.arn]
  }
  statement {
    # Allow the Cloudwatch Event Rule and/or Scheduler  to pass the task roles to the started ECS task
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.task_execution_role.arn, aws_iam_role.task_role.arn]
  }
}
resource "aws_iam_policy" "run_task" {
  count  = local.use_scheduler || local.use_event_rule ? 1 : 0
  name   = "${var.app_name}-run-task"
  policy = data.aws_iam_policy_document.run_task_policy[0].json
}
resource "aws_iam_role_policy_attachment" "run_task_policy_to_trigger_role" {
  count      = local.use_scheduler || local.use_event_rule ? 1 : 0
  policy_arn = aws_iam_policy.run_task[0].arn
  role       = aws_iam_role.trigger[0].name
}

# --- EventBridge Scheduler ---
resource "aws_scheduler_schedule" "schedule" {
  count                        = local.use_scheduler ? 1 : 0
  name                         = "${var.app_name}-schedule"
  description                  = "Run ${var.app_name} task with the schedule: ${var.schedule.expression}"
  schedule_expression          = var.schedule.expression
  schedule_expression_timezone = var.schedule.timezone
  start_date                   = var.schedule.start_date
  end_date                     = var.schedule.end_date
  group_name                   = var.schedule.group_name
  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = local.create_new_cluster ? aws_ecs_cluster.new_cluster[0].arn : var.existing_ecs_cluster.arn
    role_arn = aws_iam_role.trigger[0].arn
    ecs_parameters {
      task_count          = 1
      task_definition_arn = aws_ecs_task_definition.task_def.arn
      launch_type         = "FARGATE"
      network_configuration {
        security_groups = concat([aws_security_group.fargate_sg.id], var.security_groups)
        subnets         = var.private_subnet_ids
      }
    }
  }
}

# --- EventBridge Event Trigger ---
resource "aws_cloudwatch_event_rule" "event_trigger" {
  count         = local.use_event_rule ? 1 : 0
  name          = "${var.app_name}-event-rule"
  description   = "Run ${var.app_name} triggered by an event pattern"
  event_pattern = var.event.pattern
}

resource "aws_cloudwatch_event_target" "event_target" {
  count     = local.use_event_rule ? 1 : 0
  target_id = "${var.app_name}-event-target"
  rule      = aws_cloudwatch_event_rule.event_trigger[0].name
  arn       = local.create_new_cluster ? aws_ecs_cluster.new_cluster[0].arn : var.existing_ecs_cluster.arn
  role_arn  = aws_iam_role.trigger[0].arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.task_def.arn
    launch_type         = "FARGATE"
    network_configuration {
      security_groups = concat([aws_security_group.fargate_sg.id], var.security_groups)
      subnets         = var.private_subnet_ids
    }
  }
}

# ==================== CloudWatch Logs ====================
resource "aws_cloudwatch_log_group" "container_log_group" {
  name              = local.cloudwatch_log_group_name
  retention_in_days = var.log_retention_in_days
  tags              = var.tags
}
