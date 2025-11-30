# 1. Creación de la VPC (Red Virtual Privada)
resource "aws_vpc" "cnn_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# 2. Creación del Internet Gateway (IGW)
resource "aws_internet_gateway" "cnn_igw" {
  vpc_id = aws_vpc.cnn_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# 3. Creación de Subredes Públicas
resource "aws_subnet" "public_subnets" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.cnn_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index}"
  }
}

# 4. Creación de Subredes Privadas (Para EKS)
resource "aws_subnet" "private_subnets" {
  count             = var.az_count
  vpc_id            = aws_vpc.cnn_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 2) 
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index}"
    "kubernetes.io/cluster/${var.project_name}-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"                       = "1"
  }
}

# IP Elásticas (Necesarias para el NAT Gateway)
resource "aws_eip" "nat_eip" {
  count = var.az_count
}

# 5. Tablas de Ruteo y NAT Gateway
resource "aws_nat_gateway" "cnn_nat" {
  count         = var.az_count
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id

  tags = {
    Name = "${var.project_name}-nat-${count.index}"
  }
}

# *Omitimos la configuración completa de las tablas de ruteo por ahora,
# para avanzar con el despliegue del EKS.*