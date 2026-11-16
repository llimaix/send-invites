############################################
# Datos existentes (no se crean)
############################################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Solo AZ donde el tipo de instancia está disponible (t4g no está en todas).
data "aws_ec2_instance_type_offerings" "available" {
  location_type = "availability-zone"

  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
}

# AMI oficial de Canonical: Ubuntu 24.04 LTS arm64, publicada en SSM.
data "aws_ssm_parameter" "ubuntu_arm64" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/arm64/hvm/ebs-gp3/ami-id"
}

data "aws_route53_zone" "main" {
  name         = var.domain
  private_zone = false
}

############################################
# Red mínima (la cuenta no tiene VPC por defecto)
# Sin NAT Gateway: la única subred es pública. Costo $0.
############################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.project
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = var.project
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = sort(data.aws_ec2_instance_type_offerings.available.locations)[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project}-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

############################################
# Security Group
############################################

resource "aws_security_group" "app" {
  name        = "${var.project}-app"
  description = "send-invites: HTTP/HTTPS publico (Caddy) y SSH segun admin_cidr"
  vpc_id      = aws_vpc.main.id
}

# 80: reto HTTP-01 de Let's Encrypt y redirección a HTTPS.
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP (ACME y redireccion)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# 443: Caddy. n8n y Evolution se restringen a admin_cidr dentro de Caddy,
# porque los tres servicios comparten este puerto.
resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS (Caddy)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# PENDIENTE DE SEGURIDAD: admin_cidr está temporalmente en 0.0.0.0/0 por decisión
# de Luis. Cerrar a su IP /32 antes del envío real.
resource "aws_vpc_security_group_ingress_rule" "ssh_admin" {
  security_group_id = aws_security_group.app.id
  description       = "SSH desde admin_cidr"
  cidr_ipv4         = var.admin_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.app.id
  description       = "Salida a internet (WhatsApp, imagenes, APT, AWS APIs)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

############################################
# IAM: solo Query sobre el índice de RSVP
############################################

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.project}-ec2"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "rsvp_read" {
  statement {
    sid     = "QueryRsvpByPhone"
    actions = ["dynamodb:Query"]
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/${var.guests_table_name}/index/${var.guests_index_name}",
    ]
  }
}

resource "aws_iam_role_policy" "rsvp_read" {
  name   = "rsvp-query-phone-index"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.rsvp_read.json
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project}-ec2"
  role = aws_iam_role.app.name
}

############################################
# EC2
############################################

resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.ubuntu_arm64.insecure_value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name
  user_data              = file("${path.module}/user_data.sh")

  metadata_options {
    http_tokens = "required" # IMDSv2 obligatorio
    # 2 saltos: los contenedores (n8n) necesitan llegar al IMDS para usar el rol.
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = var.project
  }

  lifecycle {
    # Evita reemplazar la instancia cuando Canonical publique una AMI nueva
    # o cambie el user_data (solo corre en el primer arranque).
    ignore_changes = [ami, user_data]
  }
}

resource "aws_eip" "app" {
  domain   = "vpc"
  instance = aws_instance.app.id

  tags = {
    Name = var.project
  }

  depends_on = [aws_internet_gateway.main]
}

############################################
# DNS
############################################

resource "aws_route53_record" "app" {
  for_each = var.subdomains

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${each.value}.${var.domain}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.app.public_ip]
}
