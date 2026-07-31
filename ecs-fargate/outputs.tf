output "alb_dns_name" {
  description = "ECS Application Load Balancer DNS name"
  value       = aws_lb.ecs.dns_name
}
