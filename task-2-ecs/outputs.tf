# Public URL of the Flask application served through the ALB.
output "application_url" {
  description = "Public URL for the containerized application."
  value       = "http://${aws_lb.main.dns_name}/"
}

# Health check endpoint used by the ALB and for manual verification.
output "health_url" {
  description = "Health check endpoint."
  value       = "http://${aws_lb.main.dns_name}/health"
}

# Endpoint that confirms all required environment variables are loaded.
output "config_url" {
  description = "Configuration verification endpoint."
  value       = "http://${aws_lb.main.dns_name}/config"
}

# ECR repository where the application Docker image is stored.
output "ecr_repository_url" {
  description = "ECR repository URL for the application image."
  value       = aws_ecr_repository.app.repository_url
}

# Name of the ECS cluster running the application.
output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.main.name
}

# Name of the ECS service that keeps the desired task count running.
output "ecs_service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.app.name
}
