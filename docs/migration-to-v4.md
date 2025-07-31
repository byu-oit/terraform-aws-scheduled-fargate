# Migration to v4
V4 has a significant amount of breaking changes from v3 and earlier:

* How we use an existing ECS cluster allowing the creating of a cluster alongside using it as an existing cluster in the same terraform configuration.
* This module now uses the [EventBridge Scheduler](https://docs.aws.amazon.com/eventbridge/latest/userguide/scheduler.html) instead of CloudWatch EventBridge Rules.

## For scheduled tasks
1. Change `schedule_expression` variable to be inside the `expression` block
2. Remove `event_role_arn`
3. Change `ecs_cluster` output to `new_ecs_cluster` output if you're using it
   > **Note:** that the `new_ecs_cluster` will only be populated if you let the module create the cluster, if you provide your own existing cluster this output will be `null`

```diff
module "scheduled_fargate" {
-  source = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v3.0.1"
  source = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v4.1.0"
  app_name = "test-scheduled-fargate-dev"
-  schedule_expression = "rate(5 minutes)"
+  schedule = {
+    expression = "rate(5 minutes)"
+  }  
  primary_container_definition = {
    # ...
  }
-  event_role_arn                = module.acs.power_builder_role.arn
  vpc_id                        = module.acs.vpc.id
  private_subnet_ids            = module.acs.private_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
}
```

## For event triggered tasks
1. Change the `event_pattern` variable to be inside the `event` block
2. Remove `event_role_arn`
3. Change `ecs_cluster` output to `new_ecs_cluster` output if you're using it
    > **Note:** that the `new_ecs_cluster` will only be populated if you let the module create the cluster, if you provide your own existing cluster this output will be `null`

```diff
module "scheduled_fargate" {
-  source = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v3.0.1"
+  source = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v4.1.0"
  app_name      = "event-triggered-fargate-example-dev"
-  event_pattern = <<EOF
+  event = {
+    pattern = <<EOF
  {
    "source": ["aws.s3"],
    "detail-type": ["Object Created"],
    "detail": {
      "bucket": {
        "name": ["${aws_s3_bucket.test_bucket.bucket}"]
      }
    }
  }
EOF
+  }
  primary_container_definition = {
    # ...
  }
-  event_role_arn                = module.acs.power_builder_role.arn
  vpc_id                        = module.acs.vpc.id
  private_subnet_ids            = module.acs.private_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
}
```

View the release notes for more detailed changes
