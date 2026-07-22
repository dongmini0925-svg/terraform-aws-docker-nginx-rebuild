output "alb_dns_name" {
  description = "ALB DNS Name"
  value       = aws_lb.my_alb.dns_name
}

output "alb_url" {
  description = "ALB Web URL"
  value       = "http://${aws_lb.my_alb.dns_name}"
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group Name"
  value       = aws_autoscaling_group.my_asg.name
}

output "launch_template_id" {
  description = "Launch Template ID"
  value       = aws_launch_template.my_launch_template.id
}