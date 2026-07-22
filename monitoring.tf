variable "alert_email" {
  description = "CloudWatch 장애 알림을 받을 이메일 주소"
  type        = string
}

# 장애 알림용 SNS Topic
resource "aws_sns_topic" "alarm_notifications" {
  name = "my-asg-alarm-notifications"

  tags = {
    Name = "my-asg-alarm-notifications"
  }
}

# 이메일 구독
resource "aws_sns_topic_subscription" "email_notification" {
  topic_arn = aws_sns_topic.alarm_notifications.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Target Group 비정상 EC2 감지
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name        = "my-asg-unhealthy-hosts"
  alarm_description = "ALB Target Group에 비정상 EC2가 발생했습니다."

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"
  statistic   = "Maximum"
  period      = 60

  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  evaluation_periods  = 1
  datapoints_to_alarm = 1

  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.my_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.my_target_group.arn_suffix
  }

  alarm_actions = [
    aws_sns_topic.alarm_notifications.arn
  ]

  ok_actions = [
    aws_sns_topic.alarm_notifications.arn
  ]

  tags = {
    Name = "my-asg-unhealthy-hosts"
  }
}
resource "aws_cloudwatch_log_group" "user_data" {
  name              = "/aws/ec2/my-asg/user-data"
  retention_in_days = 7

  tags = {
    Name = "my-asg-user-data-logs"
  }
}

resource "aws_cloudwatch_log_group" "docker" {
  name              = "/aws/ec2/my-asg/docker"
  retention_in_days = 7

  tags = {
    Name = "my-asg-docker-logs"
  }
}