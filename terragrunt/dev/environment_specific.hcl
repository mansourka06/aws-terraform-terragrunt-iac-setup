locals {
  aws_region  = "eu-west-1"
  account_id  = "111111111111"   # ← replace with your AWS account ID

  # VPC settings — small range for dev
  vpc_cidr             = "10.10.0.0/16"
  public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24"]
  private_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24"]
  availability_zones   = ["eu-west-1a", "eu-west-1b"]

  # EC2
  ami_id        = "ami-0694d931cee176e7d"  # Amazon Linux 2023 eu-west-1
  instance_type = "t3.micro"

  # DB
  db_instance_class = "db.t3.medium"
  db_reader_count   = 0   # no reader in dev — saves cost

  # ACM certificate (wildcard or specific domain)
  acm_certificate_arn = "arn:aws:acm:eu-west-1:111111111111:certificate/REPLACE-ME"

  # ASG sizing
  asg_desired = 1
  asg_min     = 1
  asg_max     = 2

  log_retention_days             = 7
  backup_retention_days          = 1
  db_connection_alarm_threshold  = 30
}
