output "application_url" {
  description = "Public URL after the ECS service becomes healthy."
  value       = "http://${aws_lb.app.dns_name}"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "s3_bucket_name" {
  value = aws_s3_bucket.data.bucket
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}
