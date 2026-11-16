output "public_ip" {
  description = "IP elástica de la instancia."
  value       = aws_eip.app.public_ip
}

output "instance_id" {
  description = "ID de la instancia EC2."
  value       = aws_instance.app.id
}

output "urls" {
  description = "URLs de los servicios (servicio => URL)."
  value       = { for svc, sub in var.subdomains : svc => "https://${sub}.${var.domain}" }
}

output "ssh_command" {
  description = "Comando SSH (ajusta la ruta del .pem)."
  value       = "ssh -i <ruta>/${var.key_name}.pem ubuntu@${aws_eip.app.public_ip}"
}
