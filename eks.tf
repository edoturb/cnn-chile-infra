# 1. Obtenemos la información del usuario/rol que está ejecutando Terraform.
# data "aws_caller_identity" "current" {}

# # 2. Módulo principal de EKS
# module "eks" {
#   source  = "terraform-aws-modules/eks/aws"
#   version = "17.21.0" # <--- ¡VERSION ESTABLE Y CONOCIDA!

#   cluster_name    = "${var.project_name}-eks-cluster"
#   cluster_version = "1.28"

#   vpc_id                   = aws_vpc.cnn_vpc.id
#   subnet_ids               = aws_subnet.private_subnets[*].id 
#   # control_plane_subnet_ids: ELIMINADA, ya no es necesaria en esta versión.

#   # === FIX para Voclabs: Configuración de IAM en versión 17.x ===
#   # Este argumento SÍ funciona en la versión 17.x y es la clave para la autenticación.
#   map_roles = [
#     {
#       rolearn  = data.aws_caller_identity.current.arn # ARN de tu sesión actual (voclabs)
#       username = "terraform-admin"
#       groups   = ["system:masters"] # Administrador con permisos totales
#     },
#   ]
#   # =============================================================
  
#   eks_managed_node_groups = {
#     node_group_default = {
#     #   instance_types = ["t3.medium"]
#       min_size       = 2
#       max_size       = 5
#       desired_size   = 3
#     }
#   }

#   tags = {
#     "kubernetes.io/cluster/${var.project_name}-eks-cluster" = "owned"
#   }
# }

# output "cluster_name" {
#   description = "Nombre del clúster EKS creado"
#   value       = module.eks.cluster_name
# }