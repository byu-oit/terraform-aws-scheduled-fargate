provider "aws" {
  version = ">= 3.69"
  region  = "us-west-2"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v3.5.0"
}

resource "aws_s3_bucket" "test_bucket" {
  bucket = "event-triggered-fargate-example-dev"
}

resource "aws_s3_bucket_notification" "notify_eventbridge" {
  bucket      = aws_s3_bucket.test_bucket.bucket
  eventbridge = true
}

module "scheduled_fargate" {
  #  source              = "github.com/byu-oit/terraform-aws-scheduled-fargate?ref=v2.3.1"
  source        = "../../"
  app_name      = "event-triggered-fargate-example-dev"
  event_pattern = <<EOF
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
  primary_container_definition = {
    name                  = "test"
    image                 = "hello-world"
    command               = null
    environment_variables = {}
    secrets               = {}
    efs_volume_mounts     = null
  }
  event_role_arn                = module.acs.power_builder_role.arn
  vpc_id                        = module.acs.vpc.id
  private_subnet_ids            = module.acs.private_subnet_ids
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn

  tags = {
    app = "testing-event-triggered-fargate"
  }
}
