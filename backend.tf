terraform {
  backend "s3" {
    bucket       = "aws-network-rebuild-terraform-state"
    key          = "terraform/state/terraform.tfstate"
    region       = "ap-northeast-2"
    use_lockfile = true
    encrypt      = true
  }
}