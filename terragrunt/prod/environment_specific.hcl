locals {
  aws_region  = "eu-west-1"
  account_id  = "333333333333"   # ← replace with your production account ID

  vpc_cidr             = "10.30.0.0/16"
  public_subnet_cidrs  = ["10.30.1.0/24", "10.30.2.0/24", "10.30.3.0/24"]
  private_subnet_cidrs = ["10.30.11.0/24", "10.30.12.0/24", "10.30.13.0/24"]
  availability_zones   = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]

  ami_id        = "ami-0694d931cee176e7d"
  instance_type = "t3.medium"   # bigger for prod load

  db_instance_class = "db.r6g.large"   # memory-optimised for prod
  db_reader_count   = 2                # two readers — HA + read scaling

  acm_certificate_arn = "arn:aws:acm:eu-west-1:333333333333:certificate/REPLACE-ME"

  asg_desired = 3
  asg_min     = 3   # always keep 3 (one per AZ)
  asg_max     = 9

  log_retention_days             = 90
  backup_retention_days          = 14
  db_connection_alarm_threshold  = 200
}
