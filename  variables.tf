# Região AWS
variable "aws_region" {
  default     = "us-east-2"
  description = "A região da AWS onde os recursos serão criados"
}

# Tipo de instância EC2
variable "instance_type" {
  default     = "t2.micro"
  description = "Tipo de instância para o Auto Scaling Group"
}

# Banco de dados
variable "db_name" {
  description = "Nome do banco de dados RDS"
  default     = "appdb"
}

variable "db_username" {
  description = "Usuário do banco de dados RDS"
  default     = "admin"
}

variable "db_password" {
  description = "Senha do banco de dados RDS"
  type        = string
}

# Lista de Zonas de Disponibilidade
variable "availability_zones" {
  description = "Lista de zonas de disponibilidade para as subnets"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}
