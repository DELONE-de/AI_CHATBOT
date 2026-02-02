terraform {
  backend "s3" {
    bucket = "my2007-terraform-state-bucket"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}