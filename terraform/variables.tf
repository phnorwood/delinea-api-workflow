# --- Delinea Secret Server -------------------------------------------------
# AWS credentials are fetched from Secret Server at apply time (see main.tf).
# Set the auth values via environment: TF_VAR_tss_username, TF_VAR_tss_password.

variable "tss_server_url" {
  description = "Secret Server base URL, e.g. https://host/SecretServer."
  type        = string
}

variable "tss_token" {
  description = "Secret Server OAuth bearer token, provided out of band. Set via TF_VAR_tss_token."
  type        = string
  sensitive   = true
}

variable "tss_secret_id" {
  description = "ID of the Secret Server secret holding the AWS credentials."
  type        = number
}

variable "aws_access_key_slug" {
  description = "Field slug for the AWS access key in the secret template."
  type        = string
  default     = "access-key"
}

variable "aws_secret_key_slug" {
  description = "Field slug for the AWS secret key in the secret template."
  type        = string
  default     = "secret-key"
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
