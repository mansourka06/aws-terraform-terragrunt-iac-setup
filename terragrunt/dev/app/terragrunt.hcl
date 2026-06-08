include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("environment_specific.hcl"))
  e        = local.env_vars.locals
}

# The app module depends on the db module so it can receive the app_sg_id
dependency "db" {
  config_path = "../db"

  # Provide mock outputs so `terragrunt validate` works without a live state
  mock_outputs = {
    app_sg_id = "sg-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../terraform/app"
}

inputs = {
  # Networking — these would come from a vpc module in a real setup;
  # hardcoded here for clarity (replace with dependency outputs)
  vpc_id             = "vpc-REPLACE-ME"
  vpc_cidr           = local.e.vpc_cidr
  public_subnet_ids  = ["subnet-PUB1", "subnet-PUB2"]
  private_subnet_ids = ["subnet-PRIV1", "subnet-PRIV2"]

  # Compute
  ami_id        = local.e.ami_id
  instance_type = local.e.instance_type

  # ALB / TLS
  acm_certificate_arn = local.e.acm_certificate_arn

  # ASG
  asg_desired = local.e.asg_desired
  asg_min     = local.e.asg_min
  asg_max     = local.e.asg_max

  # Misc
  log_retention_days = local.e.log_retention_days
}
