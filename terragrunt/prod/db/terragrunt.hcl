include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("environment_specific.hcl"))
  e        = local.env_vars.locals
}

dependency "app" {
  config_path = "../app"

  mock_outputs = {
    app_sg_id = "sg-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../terraform/db"
}

inputs = {
  vpc_id             = "vpc-REPLACE-ME-PROD"
  private_subnet_ids = ["subnet-PRIV1", "subnet-PRIV2", "subnet-PRIV3"]
  app_sg_id          = dependency.app.outputs.app_sg_id

  db_instance_class             = local.e.db_instance_class
  db_reader_count               = local.e.db_reader_count
  backup_retention_days         = local.e.backup_retention_days
  db_connection_alarm_threshold = local.e.db_connection_alarm_threshold

  # Password is injected by CI/CD — never committed to git
  db_master_password = get_env("TF_VAR_DB_MASTER_PASSWORD")
}
