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
  tags = { Name = "escolaronline-vpc" }
}

resource "aws_subnet" "pub_1a" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.0.0/26"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name                     = "escolaronline-subnet-pub-1a"
    "kubernetes.io/role/elb" = "1"
  }
}
resource "aws_subnet" "pub_1b" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.0.64/26"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = {
    Name                     = "escolaronline-subnet-pub-1b"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "priv_app_1a" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.1.0/25"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name                              = "escolaronline-subnet-priv-app-1a"
    "kubernetes.io/role/internal-elb" = "1"
  }
}
resource "aws_subnet" "priv_app_1b" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.1.128/25"
  availability_zone = "${var.aws_region}b"
  tags = {
    Name                              = "escolaronline-subnet-priv-app-1b"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "priv_data_1a" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.2.0/26"
  availability_zone = "${var.aws_region}a"
  tags = { Name = "escolaronline-subnet-priv-data-1a" }
}
resource "aws_subnet" "priv_data_1b" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.2.64/26"
  availability_zone = "${var.aws_region}b"
  tags = { Name = "escolaronline-subnet-priv-data-1b" }
}

# ==========================================
# 2. GATEWAYS Y TABLAS DE RUTAS
# ==========================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = { Name = "escolaronline-igw" }
}

resource "aws_eip" "nat_eip" { domain = "vpc" }

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.pub_1a.id
  tags = { Name = "escolaronline-nat" }
}

resource "aws_route_table" "rt_pub" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "escolaronline-rt-pub" }
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
  tags = { Name = "escolaronline-rt-priv" }
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
  name   = "SG-ALB"
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
  name   = "SG-EKS"
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
  name   = "SG-RDS"
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
  name       = "escolaronline-rds-subnet-group"
  subnet_ids = [aws_subnet.priv_data_1a.id, aws_subnet.priv_data_1b.id]
}

resource "aws_db_instance" "escolaronline_db" {
  identifier             = "escolaronline-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  db_name                = "escolar_online"
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
  name     = "escolaronline-cluster"
  role_arn = local.lab_role_arn
  version  = "1.29"

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
  node_group_name = "escolaronline-nodes"
  node_role_arn   = local.lab_role_arn
  subnet_ids      = [aws_subnet.priv_app_1a.id, aws_subnet.priv_app_1b.id]
  instance_types  = ["t4g.small"]
  
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
  ami                    = data.aws_ami.ubuntu_arm64.id
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.priv_app_1a.id
  vpc_security_group_ids = [aws_security_group.sg_eks.id]
  iam_instance_profile   = "LabInstanceProfile"

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io git unzip curl mysql-client jq
              systemctl enable --now docker
              usermod -aG docker ubuntu

              # Instalar AWS CLI v2
              curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
              unzip -q awscliv2.zip
              ./aws/install

              # Instalar kubectl
              curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.29.0/2024-01-04/bin/linux/arm64/kubectl
              chmod +x ./kubectl
              mv ./kubectl /usr/local/bin/kubectl

              # Clonar repositorio
              git clone ${var.github_repo_url} /home/ubuntu/Escolar-Online-EKS
              chown -R ubuntu:ubuntu /home/ubuntu/Escolar-Online-EKS
              EOF

  tags = { Name = "Workspace-EKS-Admin" }
}