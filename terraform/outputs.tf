output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IP of the NGINX web server."
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "URL to reach the NGINX web server."
  value       = "http://${aws_instance.web.public_ip}"
}

output "ssh_private_key_path" {
  description = "Path to the generated SSH private key."
  value       = local_sensitive_file.private_key.filename
}
