variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ssh_public_key" {
  type        = string
  description = "RSA public key to register as the EC2 key pair"
}
