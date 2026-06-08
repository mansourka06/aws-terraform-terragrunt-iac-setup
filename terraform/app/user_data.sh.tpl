#!/usr/bin/env bash
# Bootstrap script for the webapp app tier
# Rendered by Terraform templatefile()
set -euo pipefail

APP_PORT="${app_port}"
ENVIRONMENT="${environment}"

# ── System updates ──────────────────────────────────────────
yum update -y
yum install -y amazon-cloudwatch-agent amazon-ssm-agent

# ── Start SSM Agent ─────────────────────────────────────────
systemctl enable amazon-ssm-agent
systemctl start  amazon-ssm-agent

# ── CloudWatch agent config ─────────────────────────────────
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CW_EOF'
{
  "agent": { "metrics_collection_interval": 60 },
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "mem":  { "measurement": ["mem_used_percent"] },
      "disk": { "measurement": ["disk_used_percent"], "resources": ["/"] }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          { "file_path": "/var/log/app/*.log", "log_group_name": "/app/$ENVIRONMENT/app" }
        ]
      }
    }
  }
}
CW_EOF
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# ── Placeholder: install & start your actual application ────
# Replace the block below with your real deployment steps
# (pull from S3/ECR, run docker, install via package manager, etc.)
mkdir -p /var/log/app
cat > /usr/local/bin/healthcheck.sh <<HEALTH_EOF
#!/bin/bash
echo "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nOK" | nc -l "$APP_PORT" -q 1
HEALTH_EOF
chmod +x /usr/local/bin/healthcheck.sh

echo "Bootstrap complete – environment: $ENVIRONMENT, port: $APP_PORT"
