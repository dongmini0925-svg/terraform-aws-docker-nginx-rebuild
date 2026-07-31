variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Common resource name prefix"
  type        = string
  default     = "docker-nginx-fargate"
}
