variable "project" {
  description = "Nombre del proyecto; prefijo de los recursos y tag Project."
  type        = string
  default     = "send-invites"
}

variable "aws_region" {
  description = "Región de AWS. La misma que rodolfo-invite."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Perfil de AWS CLI con el que se autentica Terraform."
  type        = string
  default     = "terraform"
}

variable "instance_type" {
  description = "Tipo de instancia EC2. Debe ser Graviton (arm64) porque la AMI es arm64."
  type        = string
  default     = "t4g.large"

  validation {
    condition     = can(regex("^(t4g|m7g|m8g|c7g|c8g|r7g|r8g)\\.", var.instance_type))
    error_message = "La AMI es arm64: usa una familia Graviton (t4g, m7g, c7g, ...)."
  }
}

variable "root_volume_size" {
  description = "Tamaño en GiB del disco raíz gp3 (cifrado)."
  type        = number
  default     = 30
}

variable "key_name" {
  description = "Nombre del key pair de EC2 ya existente para SSH."
  type        = string
  default     = "rodo-invites"
}

variable "vpc_cidr" {
  description = "Rango de la VPC del proyecto. La subred pública usa el /24 número 1 de este rango."
  type        = string
  default     = "10.60.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && endswith(var.vpc_cidr, "/16")
    error_message = "vpc_cidr debe ser un bloque /16 válido (p. ej. 10.60.0.0/16)."
  }
}

variable "admin_cidr" {
  description = "Origen permitido para SSH (22) y, en Caddy, para n8n y Evolution. Lo ideal es la IP de Luis en /32. Se acepta 0.0.0.0/0 TEMPORALMENTE (con auth básica en Caddy); cerrarlo antes del envío real."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && (endswith(var.admin_cidr, "/32") || var.admin_cidr == "0.0.0.0/0")
    error_message = "admin_cidr debe ser una IP x.x.x.x/32, o 0.0.0.0/0 de forma temporal."
  }
}

variable "domain" {
  description = "Zona pública de Route 53 bajo la que se crean los subdominios."
  type        = string
  default     = "isdomana.com"
}

variable "subdomains" {
  description = "Subdominios que apuntan a la EIP de la instancia (servicio => subdominio)."
  type        = map(string)
  default = {
    chatwoot  = "chat"
    n8n       = "n8n"
    evolution = "evo"
  }
}

variable "guests_table_name" {
  description = "Nombre de la tabla DynamoDB de RSVP de rodolfo-invite (p. ej. rodolfo-invite-guests-prod). Solo se otorga Query sobre su índice phone-index."
  type        = string
}

variable "guests_index_name" {
  description = "GSI de la tabla de RSVP que se consulta por los últimos 8 dígitos del teléfono."
  type        = string
  default     = "phone-index"
}
