variable "aws_region" {
  description = "La región de AWS donde se desplegará la infraestructura."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo usado para nombrar los recursos."
  type        = string
  default     = "cnn-chile"
}

variable "vpc_cidr" {
  description = "CIDR block para la VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Número de zonas de disponibilidad a usar."
  type        = number
  default     = 2
}
