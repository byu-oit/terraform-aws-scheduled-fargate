output "new_ecs_cluster" {
  value = local.create_new_cluster ? aws_ecs_cluster.new_cluster[0] : null
}

output "fargate_security_group" {
  value = aws_security_group.fargate_sg
}

output "task_definition" {
  value = aws_ecs_task_definition.task_def
}

output "schedule" {
  value     = local.use_scheduler ? aws_scheduler_schedule.schedule[0] : null
  sensitive = true
}

output "event_rule" {
  value = local.use_event_rule ? aws_cloudwatch_event_rule.event_trigger[0] : null
}

output "event_target" {
  value = local.use_event_rule ? aws_cloudwatch_event_target.event_target[0] : null
}

output "log_group" {
  value = aws_cloudwatch_log_group.container_log_group
}

output "task_execution_role" {
  value = aws_iam_role.task_execution_role
}

output "task_role" {
  value = aws_iam_role.task_role
}

output "run_task_cli_command" {
  value     = <<EOT
aws ecs run-task \
--task-definition ${aws_ecs_task_definition.task_def.id} \
--cluster ${local.create_new_cluster ? aws_ecs_cluster.new_cluster[0].name : var.existing_ecs_cluster.arn} \
--network-configuration "{\"awsvpcConfiguration\":{\"subnets\":[\"${var.private_subnet_ids[0]}\"],\"securityGroups\":[\"${aws_security_group.fargate_sg.id}\"]}}" \
--launch-type FARGATE \
--propagate-tags TASK_DEFINITION
EOT
  sensitive = true
}
