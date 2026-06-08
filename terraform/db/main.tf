# ============================================================
# MODULE: db
# Deploys an Amazon Aurora PostgreSQL cluster (Multi-AZ) with
# a dedicated security group that only allows traffic from
# the app tier security group.
# ============================================================

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── Security Group ──────────────────────────────────────────
resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db-sg"
  description = "Allow PostgreSQL from app tier only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from app tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.app_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${local.name_prefix}-db-sg" })
}

# ── DB Subnet Group ─────────────────────────────────────────
resource "aws_db_subnet_group" "db" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = merge(var.common_tags, { Name = "${local.name_prefix}-db-subnet-group" })
}

# ── Parameter Group ─────────────────────────────────────────
resource "aws_rds_cluster_parameter_group" "db" {
  name        = "${local.name_prefix}-cluster-pg"
  family      = "aurora-postgresql15"
  description = "Aurora PostgreSQL 15 cluster parameter group for ${local.name_prefix}"

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # log queries > 1 s
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  tags = var.common_tags
}

# ── KMS key for Aurora encryption ───────────────────────────
resource "aws_kms_key" "db" {
  description             = "KMS key for ${local.name_prefix} Aurora cluster"
  deletion_window_in_days = 14
  enable_key_rotation     = true
  tags                    = var.common_tags
}

resource "aws_kms_alias" "db" {
  name          = "alias/${local.name_prefix}-aurora"
  target_key_id = aws_kms_key.db.key_id
}

# ── Secrets Manager for DB credentials ──────────────────────
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${local.name_prefix}/db/master-password"
  kms_key_id              = aws_kms_key.db.key_id
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  tags                    = var.common_tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = var.db_master_password
    host     = aws_rds_cluster.db.endpoint
    port     = 5432
    dbname   = var.db_name
  })
}

# ── Aurora PostgreSQL Cluster ────────────────────────────────
resource "aws_rds_cluster" "db" {
  cluster_identifier              = "${local.name_prefix}-aurora-cluster"
  engine                          = "aurora-postgresql"
  engine_version                  = "15.4"
  database_name                   = var.db_name
  master_username                 = var.db_master_username
  master_password                 = var.db_master_password
  db_subnet_group_name            = aws_db_subnet_group.db.name
  vpc_security_group_ids          = [aws_security_group.db.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.db.name

  storage_encrypted = true
  kms_key_id        = aws_kms_key.db.arn

  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = "02:00-03:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  deletion_protection             = var.environment == "prod" ? true : false
  skip_final_snapshot             = var.environment != "prod"
  final_snapshot_identifier       = var.environment == "prod" ? "${local.name_prefix}-final-snapshot" : null

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(var.common_tags, { Name = "${local.name_prefix}-aurora-cluster" })
}

# ── Aurora Instances (writer + reader(s)) ────────────────────
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${local.name_prefix}-aurora-writer"
  cluster_identifier = aws_rds_cluster.db.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.db.engine
  engine_version     = aws_rds_cluster.db.engine_version

  db_subnet_group_name    = aws_db_subnet_group.db.name
  monitoring_interval     = 60
  monitoring_role_arn     = aws_iam_role.rds_enhanced_monitoring.arn
  performance_insights_enabled = true
  performance_insights_kms_key_id = aws_kms_key.db.arn

  tags = merge(var.common_tags, { Name = "${local.name_prefix}-aurora-writer" })
}

resource "aws_rds_cluster_instance" "reader" {
  count = var.db_reader_count

  identifier         = "${local.name_prefix}-aurora-reader-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.db.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.db.engine
  engine_version     = aws_rds_cluster.db.engine_version

  db_subnet_group_name         = aws_db_subnet_group.db.name
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_enhanced_monitoring.arn
  performance_insights_enabled = true
  performance_insights_kms_key_id = aws_kms_key.db.arn

  tags = merge(var.common_tags, { Name = "${local.name_prefix}-aurora-reader-${count.index + 1}" })
}

# ── Enhanced Monitoring IAM Role ─────────────────────────────
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${local.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ── CloudWatch Alarms ────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "db_cpu" {
  alarm_name          = "${local.name_prefix}-db-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  dimensions          = { DBClusterIdentifier = aws_rds_cluster.db.cluster_identifier }
  alarm_description   = "Aurora cluster CPU above 80%"
  tags                = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "db_connections" {
  alarm_name          = "${local.name_prefix}-db-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 120
  statistic           = "Average"
  threshold           = var.db_connection_alarm_threshold
  dimensions          = { DBClusterIdentifier = aws_rds_cluster.db.cluster_identifier }
  alarm_description   = "Aurora connection count is high"
  tags                = var.common_tags
}
