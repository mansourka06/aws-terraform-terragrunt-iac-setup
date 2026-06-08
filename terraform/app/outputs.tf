output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB (for Route 53 alias records)"
  value       = aws_lb.app.zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.app.arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "app_sg_id" {
  description = "Security Group ID attached to the app instances"
  value       = aws_security_group.app.id
}

output "alb_sg_id" {
  description = "Security Group ID attached to the ALB"
  value       = aws_security_group.alb.id
}
