# AWS provider configured for the target region with shared default tags.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Networking

# Isolated network for the ALB, ECS tasks, and related resources.
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Internet gateway so public subnets can reach the internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Two public subnets across different AZs (required by the ALB).
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
}

# Route table sending all outbound traffic from public subnets to the internet.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

# Associate each public subnet with the public route table.
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Allow inbound HTTP from the internet to the load balancer.
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow public HTTP access to the load balancer."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Allow inbound app traffic only from the ALB security group.
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-sg"
  description = "Allow traffic from the load balancer to ECS tasks."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App traffic from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Container registry and image build

# Private Docker registry for the Flask application image.
resource "aws_ecr_repository" "app" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Build the Docker image locally and push it to ECR during terraform apply.
resource "null_resource" "docker_build_push" {
  triggers = {
    dockerfile_hash = filemd5("${path.module}/ecs-task/Dockerfile")
    app_hash        = filemd5("${path.module}/ecs-task/app.py")
    requirements    = filemd5("${path.module}/ecs-task/requirements.txt")
    repository_url  = aws_ecr_repository.app.repository_url
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command = <<-EOT
      set -euo pipefail
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}
      docker build -t ${aws_ecr_repository.app.repository_url}:latest ${path.module}/ecs-task
      docker push ${aws_ecr_repository.app.repository_url}:latest
    EOT
  }

  depends_on = [aws_ecr_repository.app]
}

# Runtime configuration (no .env baked into the Docker image)


# Non-sensitive app name stored in SSM and injected as APP_NAME.
resource "aws_ssm_parameter" "app_name" {
  name  = "/${var.project_name}/APP_NAME"
  type  = "String"
  value = var.app_name
}

# Non-sensitive database host stored in SSM and injected as DB_HOST.
resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.project_name}/DB_HOST"
  type  = "String"
  value = var.db_host
}

# Sensitive API key stored in Secrets Manager and injected as API_KEY.
resource "aws_secretsmanager_secret" "api_key" {
  name                    = "${var.project_name}-api-key"
  recovery_window_in_days = 0
}

# Secret value for the API key.
resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id     = aws_secretsmanager_secret.api_key.id
  secret_string = var.api_key
}

# Sensitive database password stored in Secrets Manager and injected as DB_PASSWORD.
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}-db-password"
  recovery_window_in_days = 0
}

# Secret value for the database password.
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

# CloudWatch log group for container stdout/stderr from Gunicorn/Flask.
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

# IAM


# Role used by the ECS agent to pull images, write logs, and fetch secrets.
resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.project_name}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

# Managed policy for ECR image pull and CloudWatch log delivery.
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Inline policy granting read access to SSM parameters and Secrets Manager secrets.
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name   = "${var.project_name}-ecs-execution-secrets"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.ecs_task_execution_secrets.json
}


# ECS


# Logical grouping for ECS services and tasks.
resource "aws_ecs_cluster" "main" {
  name = var.project_name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

# Blueprint for the Fargate container: image, ports, secrets, and logging.
resource "aws_ecs_task_definition" "app" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
        }
      ]

      # Inject env vars from AWS at startup instead of baking a .env into the image.
      secrets = [
        {
          name      = "APP_NAME"
          valueFrom = aws_ssm_parameter.app_name.arn
        },
        {
          name      = "DB_HOST"
          valueFrom = aws_ssm_parameter.db_host.arn
        },
        {
          name      = "API_KEY"
          valueFrom = aws_secretsmanager_secret.api_key.arn
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = aws_secretsmanager_secret.db_password.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  depends_on = [null_resource.docker_build_push]
}

# Keeps one Fargate task running and registers it with the ALB target group.
resource "aws_ecs_service" "app" {
  name            = var.project_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 5000
  }

  depends_on = [
    aws_lb_listener.http,
    null_resource.docker_build_push,
  ]
}

# ---------------------------------------------------------------------------
# Load balancer (public HTTP access)
# ---------------------------------------------------------------------------

# Internet-facing application load balancer in front of ECS tasks.
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

# Target group routing traffic to Fargate task IPs on port 5000.
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }
}

# HTTP listener on port 80 forwarding all requests to the target group.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
