output "ecs_cluster" {
  value = local.create_new_cluster ? aws_ecs_cluster.new_cluster[0] : data.aws_ecs_cluster.existing_cluster[0]
}

output "fargate_security_group" {
  value = aws_security_group.fargate_service_sg
}

output task_definition {
  value = aws_ecs_task_definition.task_def
}

output "event_rule" {
  value = aws_cloudwatch_event_rule.scheduled_task
}

output "event_target" {
  value = aws_cloudwatch_event_target.scheduled_task
}

output "log_group" {
  value = aws_cloudwatch_log_group.container_log_group
}
