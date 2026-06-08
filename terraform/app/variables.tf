variable "project" {
  description = "Project / application name used as a naming prefix"
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
  description = "AWS region to deploy into"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC (used for SSH ingress rule)"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EC2 instances"
  type        = list(string)
}

variable "ami_id" {
  description = "AMI ID for the app EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = ""
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "HTTP path used by the ALB health check"
  type        = string
  default     = "/health"
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate to attach to the HTTPS listener"
  type        = string
}

variable "asg_desired" {
  description = "Desired number of app instances"
  type        = number
  default     = 2
}

variable "asg_min" {
  description = "Minimum number of app instances"
  type        = number
  default     = 1
}

variable "asg_max" {
  description = "Maximum number of app instances"
  type        = number
  default     = 4
}

variable "log_retention_days" {
  description = "Number of days to retain ALB access logs in S3"
  type        = number
  default     = 30
}

variable "common_tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}
