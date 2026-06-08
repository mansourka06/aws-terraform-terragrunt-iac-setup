include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("environment_specific.hcl"))
  e        = local.env_vars.locals
}

dependency "db" {
  config_path = "../db"

  mock_outputs = {
    app_sg_id = "sg-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../terraform/app"
}

inputs = {
  vpc_id             = "vpc-REPLACE-ME-STAGING"
  vpc_cidr           = local.e.vpc_cidr
  public_subnet_ids  = ["subnet-PUB1", "subnet-PUB2", "subnet-PUB3"]
  private_subnet_ids = ["subnet-PRIV1", "subnet-PRIV2", "subnet-PRIV3"]

  ami_id        = local.e.ami_id
  instance_type = local.e.instance_type

  acm_certificate_arn = local.e.acm_certificate_arn

  asg_desired = local.e.asg_desired
  asg_min     = local.e.asg_min
  asg_max     = local.e.asg_max

  log_retention_days = local.e.log_retention_days
}
