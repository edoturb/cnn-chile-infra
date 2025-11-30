# Base de Datos Serverless (NoSQL) para Datos de Usuario (Alta Tasa de Lectura/Escritura)
# Nota: Este recurso ya está creado, Terraform lo ignorará.
resource "aws_dynamodb_table" "users_data" {
  name             = "${var.project_name}-users-data"
  hash_key         = "user_id"
  billing_mode     = "PAY_PER_REQUEST"
  read_capacity    = 0 
  write_capacity   = 0

  attribute {
    name = "user_id"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-users-data"
  }
}

# Base de Datos Gestionada (SQL) para Backoffice y Finanzas (ALTA DISPONIBILIDAD)
# Se reemplaza Serverless por un Clúster Provisionado Multi-AZ.

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-rds-subnets"
  subnet_ids = [for s in aws_subnet.private_subnets : s.id] 
}

resource "aws_rds_cluster" "backoffice_db" {
  cluster_identifier  = "${var.project_name}-backoffice-db"
  engine              = "aurora-postgresql"
  engine_version      = "14.11" # Versión de Aurora PostgreSQL estable
  database_name       = "cnnbackoffice"
  master_username     = "dbadmin"
  master_password     = "SecurePassword123" 
  skip_final_snapshot = true
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name

  # Configuraciones de réplica y alta disponibilidad
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"

  tags = {
    Name = "${var.project_name}-backoffice-db"
  }
}

# Instancias (Nodos) que corren dentro del Cluster. Se requieren 2 para Multi-AZ.
resource "aws_rds_cluster_instance" "cluster_instances" {
  count              = 2 # Crea dos instancias (nodos) para Multi-AZ y Alta Disponibilidad
  identifier         = "${var.project_name}-db-instance-${count.index}"
  cluster_identifier = aws_rds_cluster.backoffice_db.id
  instance_class     = "db.t3.medium" # Clase de instancia económica
  engine             = aws_rds_cluster.backoffice_db.engine
  engine_version     = aws_rds_cluster.backoffice_db.engine_version
  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
}