locals {
  aws_region  = "eu-west-1"
  account_id  = "222222222222"   # ← replace with your staging account ID

  vpc_cidr             = "10.20.0.0/16"
  public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
  private_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24", "10.20.13.0/24"]
  availability_zones   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

  ami_id        = "ami-0694d931cee176e7d"
  instance_type = "t3.small"

  db_instance_class = "db.t3.medium"
  db_reader_count   = 1   # one reader for staging

  acm_certificate_arn = "arn:aws:acm:eu-west-1:222222222222:certificate/REPLACE-ME"

  asg_desired = 2
  asg_min     = 1
  asg_max     = 4

  log_retention_days             = 14
  backup_retention_days          = 3
  db_connection_alarm_threshold  = 60
}
