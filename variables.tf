variable "aws_region" {
  description = "Región de AWS"
  default     = "us-east-1"
}

variable "github_repo_url" {
  description = "URL del repositorio de GitHub"
  default     = "https://github.com/Ignaciov1/Escolar-Online-EKS.git"
}

variable "db_user" {
  description = "Usuario maestro de RDS"
  default     = "alumno"
}

variable "db_password" {
  description = "Contraseña maestra de RDS"
  default     = "alumno123"
}

variable "academy_access_key" {
  description = "AWS Access Key temporal de Academy"
  type        = string
}

variable "academy_secret_key" {
  description = "AWS Secret Key temporal de Academy"
  type        = string
}

variable "academy_session_token" {
  description = "AWS Session Token temporal de Academy"
  type        = string
}