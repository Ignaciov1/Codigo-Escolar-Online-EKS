output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "rds_endpoint" {
  value = aws_db_instance.escolaronline_db.endpoint
  description = "El endpoint real que irá en tu ConfigMap (sin el puerto :3306)"
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "workspace_instance_id" {
  value = aws_instance.workspace.id
  description = "Conéctate a esta instancia por Session Manager"
}