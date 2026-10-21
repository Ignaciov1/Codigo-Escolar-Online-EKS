provider "aws" {
  region = var.aws_region
}

# Obtener Account ID actual para usar el LabRole de AWS Academy
data "aws_caller_identity" "current" {}

locals {
  lab_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
}

# ==========================================
# 1. VPC Y SUBREDES
# ==========================================
resource "aws_vpc" "eks_vpc" {
  cidr_block           = "10.0.0.0/22"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "freshbox-vpc" }
}

resource "aws_subnet" "pub_1a" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.0.0/26"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name                     = "freshbox-subnet-pub-1a"
    "kubernetes.io/role/elb" = "1"
  }
}
resource "aws_subnet" "pub_1b" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.0.64/26"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = {
    Name                     = "freshbox-subnet-pub-1b"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "priv_app_1a" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.1.0/25"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name                              = "freshbox-subnet-priv-app-1a"
    "kubernetes.io/role/internal-elb" = "1"
  }
}
resource "aws_subnet" "priv_app_1b" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.1.128/25"
  availability_zone = "${var.aws_region}b"
  tags = {
    Name                              = "freshbox-subnet-priv-app-1b"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "priv_data_1a" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.2.0/26"
  availability_zone = "${var.aws_region}a"
  tags = { Name = "freshbox-subnet-priv-data-1a" }
}
resource "aws_subnet" "priv_data_1b" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.2.64/26"
  availability_zone = "${var.aws_region}b"
  tags = { Name = "freshbox-subnet-priv-data-1b" }
}

# ==========================================
# 2. GATEWAYS Y TABLAS DE RUTAS
# ==========================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = { Name = "freshbox-igw" }
}

resource "aws_eip" "nat_eip" { domain = "vpc" }

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.pub_1a.id
  tags = { Name = "freshbox-nat" }
}

resource "aws_route_table" "rt_pub" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "freshbox-rt-pub" }
}
resource "aws_route_table_association" "rta_pub_1a" {
  subnet_id      = aws_subnet.pub_1a.id
  route_table_id = aws_route_table.rt_pub.id
}
resource "aws_route_table_association" "rta_pub_1b" {
  subnet_id      = aws_subnet.pub_1b.id
  route_table_id = aws_route_table.rt_pub.id
}

resource "aws_route_table" "rt_priv" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "freshbox-rt-priv" }
}
resource "aws_route_table_association" "rta_priv_app_1a" {
  subnet_id      = aws_subnet.priv_app_1a.id
  route_table_id = aws_route_table.rt_priv.id
}
resource "aws_route_table_association" "rta_priv_app_1b" {
  subnet_id      = aws_subnet.priv_app_1b.id
  route_table_id = aws_route_table.rt_priv.id
}
resource "aws_route_table_association" "rta_priv_data_1a" {
  subnet_id      = aws_subnet.priv_data_1a.id
  route_table_id = aws_route_table.rt_priv.id
}
resource "aws_route_table_association" "rta_priv_data_1b" {
  subnet_id      = aws_subnet.priv_data_1b.id
  route_table_id = aws_route_table.rt_priv.id
}

# ==========================================
# 3. SECURITY GROUPS
# ==========================================
resource "aws_security_group" "sg_alb" {
  name   = "SG-ALB-FreshBox"
  vpc_id = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_eks" {
  name   = "SG-EKS-FreshBox"
  vpc_id = aws_vpc.eks_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.sg_alb.id]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_rds" {
  name   = "SG-RDS-FreshBox"
  vpc_id = aws_vpc.eks_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_eks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# 4. BASE DE DATOS (RDS Multi-AZ)
# ==========================================
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "freshbox-rds-subnet-group"
  subnet_ids = [aws_subnet.priv_data_1a.id, aws_subnet.priv_data_1b.id]
}

resource "aws_db_instance" "freshbox_db" {
  identifier             = "freshbox-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  
  # ACTUALIZADO a db.t4g.small para cumplir con la rúbrica del EP2
  instance_class         = "db.t4g.small" 
  
  allocated_storage      = 20
  db_name                = "freshbox_db"
  username               = var.db_user
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.sg_rds.id]
  multi_az               = true
  skip_final_snapshot    = true
  publicly_accessible    = false
}

# ==========================================
# 5. CLUSTER EKS Y NODOS
# ==========================================
resource "aws_eks_cluster" "eks_cluster" {
  name     = "freshbox-cluster"
  role_arn = local.lab_role_arn
  
  vpc_config {
    subnet_ids = [
      aws_subnet.pub_1a.id,
      aws_subnet.pub_1b.id,
      aws_subnet.priv_app_1a.id,
      aws_subnet.priv_app_1b.id
    ]
    security_group_ids = [aws_security_group.sg_eks.id]
  }
}

resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "freshbox-nodes"
  node_role_arn   = local.lab_role_arn
  subnet_ids      = [aws_subnet.priv_app_1a.id, aws_subnet.priv_app_1b.id]
  
  # Mantenemos "t4g.medium" como indicaste para evitar problemas de cupos de red (max 34 pods)
  instance_types  = ["t4g.medium"] 
  
  ami_type        = "AL2023_ARM_64_STANDARD"
  
  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 2
  }
}

# ==========================================
# 6. INSTANCIA WORKSPACE (Sala de Control)
# ==========================================
data "aws_ami" "ubuntu_arm64" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }
}

resource "aws_instance" "workspace" {
  ami                         = data.aws_ami.ubuntu_arm64.id
  instance_type               = "t4g.small"
  subnet_id                   = aws_subnet.pub_1a.id 
  associate_public_ip_address = true 
  vpc_security_group_ids      = [aws_security_group.sg_eks.id]
  iam_instance_profile        = "LabInstanceProfile"

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y git
              
              # Clonar el repo en la nueva carpeta FreshBox-EKS
              git clone ${var.github_repo_url} /home/ubuntu/FreshBox-EKS
              chown -R ubuntu:ubuntu /home/ubuntu/FreshBox-EKS

              mkdir -p /home/ubuntu/.aws
              cat << 'EOC' > /home/ubuntu/.aws/credentials
              [default]
              aws_access_key_id = ${var.academy_access_key}
              aws_secret_access_key = ${var.academy_secret_key}
              aws_session_token = ${var.academy_session_token}
              EOC
              chown -R ubuntu:ubuntu /home/ubuntu/.aws
              EOF

  tags = { Name = "Workspace-EKS-Admin-FreshBox" }
}

# ==========================================
# CERTIFICADO AUTOFIRMADO PARA ALB INGRESS
# ==========================================
resource "tls_private_key" "alb_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb_cert_local" {
  private_key_pem = tls_private_key.alb_key.private_key_pem

  subject {
    common_name  = "freshbox.local"
    organization = "FreshBox SpA"
  }

  validity_period_hours = 8760
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "alb_acm_cert" {
  private_key      = tls_private_key.alb_key.private_key_pem
  certificate_body = tls_self_signed_cert.alb_cert_local.cert_pem
  
  tags = {
    Name = "freshbox-cert"
  }
}