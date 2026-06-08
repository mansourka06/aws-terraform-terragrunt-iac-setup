# ============================================================
# ROOT terragrunt.hcl
# Shared configuration inherited by every child module.
# ============================================================

locals {
  # Parse the path to extract environment: terragrunt/<env>/<module>
  path_parts  = split("/", path_relative_to_include())
  environment = local.path_parts[0]   # dev | staging | prod

  # Load environment-specific variables (account ID, region, VPC CIDR, etc.)
  env_vars = read_terragrunt_config(find_in_parent_folders("environment_specific.hcl"))

  aws_region  = local.env_vars.locals.aws_region
  account_id  = local.env_vars.locals.account_id
  project     = "webapp"
}

# ── Remote State (S3 + DynamoDB locking) ────────────────────
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "tfstate-${local.project}-${local.account_id}-${local.aws_region}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = "tfstate-lock-${local.project}"
    # Enable bucket versioning to recover from accidental state deletions
    s3_bucket_tags = {
      Project     = local.project
      ManagedBy   = "terragrunt"
    }
  }
}

# ── Provider generation ──────────────────────────────────────
generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.aws_region}"

      default_tags {
        tags = {
          Project     = "${local.project}"
          Environment = "${local.environment}"
          ManagedBy   = "terragrunt"
        }
      }
    }
  EOF
}

# ── Common inputs propagated to every module ─────────────────
inputs = {
  project     = local.project
  environment = local.environment
  aws_region  = local.aws_region
  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terragrunt"
  }
}
