# Configuración de Terraform y los proveedores
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Usaremos la versión más reciente compatible con tu init
    }
  }
}

# Configuración del Proveedor AWS
provider "aws" {
  region = var.aws_region # Usa la variable definida en variables.tf
}

# Data source para obtener las zonas de disponibilidad de la región
data "aws_availability_zones" "available" {
  state = "available"
}