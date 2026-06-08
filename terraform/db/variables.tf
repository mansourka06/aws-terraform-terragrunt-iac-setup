variable "project" {
  description = "Project / application name"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Aurora instances"
  type        = list(string)
}

variable "app_sg_id" {
  description = "Security Group ID of the app tier (allowed to connect to DB)"
  type        = string
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_master_username" {
  description = "Master DB username"
  type        = string
  default     = "dbadmin"
}

variable "db_master_password" {
  description = "Master DB password — store in SSM or pass via CI secrets"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Aurora instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_reader_count" {
  description = "Number of Aurora reader instances (0 for dev, 1+ for staging/prod)"
  type        = number
  default     = 0
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "db_connection_alarm_threshold" {
  description = "Number of DB connections that triggers a CloudWatch alarm"
  type        = number
  default     = 100
}

variable "common_tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}
