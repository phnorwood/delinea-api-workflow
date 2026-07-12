variable "aws_access_key" {
  description = "AWS access key ID (client id). Configurable code parameter."
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS secret access key (secret id). Configurable code parameter."
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type. Kept as small as possible."
  type        = string
  default     = "t3.micro"
}

variable "project_name" {
  description = "Name prefix applied to all created resources."
  type        = string
  default     = "minimal-nginx"
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to SSH (port 22). Restrict this to your IP in production."
  type        = string
  default     = "0.0.0.0/0"
}

variable "http_ingress_cidr" {
  description = "CIDR allowed to reach NGINX (port 80)."
  type        = string
  default     = "0.0.0.0/0"
}
