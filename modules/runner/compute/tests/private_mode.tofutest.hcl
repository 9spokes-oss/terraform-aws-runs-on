mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      dns_suffix = "amazonaws.com"
      partition  = "aws"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      unique_id = "AROATESTSTACKROLEID"
    }
  }

  mock_resource "aws_iam_instance_profile" {
    defaults = {
      arn = "arn:aws:iam::123456789012:instance-profile/test-stack-ec2-instance-profile"
    }
  }
}

variables {
  region                  = "us-east-1"
  account_id              = "123456789012"
  stack_name              = "test-stack"
  cost_allocation_tag     = "runs-on-stack-name"
  log_retention_days      = 7
  permission_boundary_arn = ""
  app_tag                 = "v0.0.0-test"
  bootstrap_tag           = "v0.0.0-test"
  ipv6_enabled            = false
  runner_max_runtime      = 360
  tags = {
    Environment          = "test"
    "runs-on-stack-name" = "test-stack"
  }

  network = {
    vpc_id             = "vpc-12345678"
    private_mode       = "false"
    public_subnet_ids  = ["subnet-12345678"]
    private_subnet_ids = []
    security_group_ids = ["sg-12345678"]
  }

  extras = {
    cache = {
      bucket_id   = "test-stack-cache"
      bucket_arn  = "arn:aws:s3:::test-stack-cache"
      bucket_name = "test-stack-cache"
    }
    efs = {
      enabled           = false
      file_system_id    = ""
      file_system_arn   = ""
      file_system_dns   = ""
      security_group_id = ""
    }
    ecr = {
      enabled         = false
      repository_arn  = ""
      repository_name = ""
      repository_url  = ""
    }
    pull_through_cache = {
      enabled           = false
      registry_url      = ""
      docker_hub_prefix = ""
      rules             = {}
    }
  }
}

run "default_templates_assign_public_ip_when_public_subnets_are_used" {
  command = plan

  assert {
    condition = alltrue([
      tostring(aws_launch_template.linux_default.network_interfaces[0].associate_public_ip_address) == "true",
      tostring(aws_launch_template.linux_default_nested.network_interfaces[0].associate_public_ip_address) == "true",
      tostring(aws_launch_template.windows_default.network_interfaces[0].associate_public_ip_address) == "true",
      tostring(aws_launch_template.windows_default_nested.network_interfaces[0].associate_public_ip_address) == "true",
    ])
    error_message = "default launch templates should assign a public IP unless private_mode is \"only\"."
  }
}

run "no_template_assigns_public_ip_when_private_mode_is_only" {
  command = plan

  variables {
    network = {
      vpc_id             = "vpc-12345678"
      private_mode       = "only"
      public_subnet_ids  = []
      private_subnet_ids = ["subnet-87654321"]
      security_group_ids = ["sg-12345678"]
    }
  }

  assert {
    condition = alltrue([
      tostring(aws_launch_template.linux_default.network_interfaces[0].associate_public_ip_address) == "false",
      tostring(aws_launch_template.linux_default_nested.network_interfaces[0].associate_public_ip_address) == "false",
      tostring(aws_launch_template.windows_default.network_interfaces[0].associate_public_ip_address) == "false",
      tostring(aws_launch_template.windows_default_nested.network_interfaces[0].associate_public_ip_address) == "false",
      tostring(aws_launch_template.linux_private.network_interfaces[0].associate_public_ip_address) == "false",
      tostring(aws_launch_template.linux_private_nested.network_interfaces[0].associate_public_ip_address) == "false",
      tostring(aws_launch_template.windows_private.network_interfaces[0].associate_public_ip_address) == "false",
      tostring(aws_launch_template.windows_private_nested.network_interfaces[0].associate_public_ip_address) == "false",
    ])
    error_message = "no launch template should assign a public IP when private_mode is \"only\" (Security Hub EC2.25)."
  }
}
