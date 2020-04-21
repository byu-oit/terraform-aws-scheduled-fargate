output "ecs_cluster" {
  value = var.ecs_cluster_arn == null ? aws_ecs_cluster.cluster : null
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
