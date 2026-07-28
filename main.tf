# EC2 보안 그룹
resource "aws_security_group" "my_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = module.network.vpc_id

  ingress {
    description = "SSH from EC2 Instance Connect"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    prefix_list_ids = [
      data.aws_ec2_managed_prefix_list.ec2_instance_connect.id
    ]
  }



  # HTTP
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.my_alb_sg.id]
  }

  # 모든 외부 통신 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }

}

# 최신 Ubuntu 24.04 x86_64 AMI 조회
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# EC2
data "aws_ec2_managed_prefix_list" "ec2_instance_connect" {
  name = "com.amazonaws.ap-northeast-2.ec2-instance-connect"
}


