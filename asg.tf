resource "aws_launch_template" "my_launch_template" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  vpc_security_group_ids = [
    aws_security_group.my_sg.id
  ]
  iam_instance_profile {
    name = aws_iam_instance_profile.cloudwatch_agent.name
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    cloudwatch_agent_config = file("${path.module}/cloudwatch-agent-config.json")
  }))
  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-asg-instance"
    }
  }
}

resource "aws_autoscaling_group" "my_asg" {
  name = "${var.project_name}-asg"

  desired_capacity = var.asg_desired_capacity
  min_size         = var.asg_min_size
  max_size         = var.asg_max_size

  vpc_zone_identifier = module.network.public_subnet_ids

  launch_template {
    id      = aws_launch_template.my_launch_template.id
    version = aws_launch_template.my_launch_template.latest_version
  }

  target_group_arns = [
    aws_lb_target_group.my_target_group.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 180
  default_instance_warmup   = 180

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }
  depends_on = [
    aws_iam_role_policy_attachment.cloudwatch_agent,
    aws_cloudwatch_log_group.user_data,
    aws_cloudwatch_log_group.docker
  ]
}
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.project_name}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.my_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 20.0
  }
}