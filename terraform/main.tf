provider "aws" {
  region         = var.aws_region
  access_key     = var.aws_access_key
  secret_key     = var.aws_secret_key
  token          = var.aws_session_token
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "Security group for ECS tasks and services"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
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

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow public HTTP traffic"
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
    description     = "Allow traffic from ECS tasks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "backend-ecs-cluster"
}

resource "aws_ecs_task_definition" "task_definition" {
  for_each = toset(var.service_names)

  family                   = each.key
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = "arn:aws:iam::905418052472:role/LabRole"
  execution_role_arn       = "arn:aws:iam::905418052472:role/LabRole"

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = "${var.dockerhub_username}/${each.key}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = each.key == "orders-service" ? [
        {
          name  = "APP_ARGS"
          value = "http://payments-service-alb-418458436.us-east-1.elb.amazonaws.com http://shipping-service-alb-1784245012.us-east-1.elb.amazonaws.com http://products-service-alb-1661164233.us-east-1.elb.amazonaws.com"
        }
      ] : null


    }
  ])
}


resource "aws_lb" "application_lbs" {
  for_each            = toset(var.service_names)
  name                = "${each.key}-alb"
  load_balancer_type  = "application"
  security_groups     = [aws_security_group.alb_sg.id]
  subnets             = data.aws_subnets.public.ids
  enable_deletion_protection = false

  tags = {
    Name = "${each.key}-alb"
  }
}

resource "aws_lb_target_group" "target_groups" {
  for_each = toset(var.service_names)

  name        = "${each.key}-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.default.id

  health_check {
    path                = lookup(var.service_health_paths, each.key, "/")
    protocol            = "HTTP"
    matcher             = "200-499"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http_listeners" {
  for_each          = aws_lb.application_lbs
  load_balancer_arn = each.value.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.target_groups[each.key].arn
      }
    }
  }
}

resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "fe-app-s3-new-acc"

  tags = {
    Environment = "Production"
    Team        = "DevOps"
  }
}

resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_bucket" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })
}

output "s3_bucket_name" {
  value = aws_s3_bucket.frontend_bucket.bucket
}

resource "aws_ecs_service" "ecs_services" {
  for_each            = aws_ecs_task_definition.task_definition
  name                = each.key
  cluster             = aws_ecs_cluster.ecs_cluster.id
  task_definition     = each.value.arn
  desired_count       = var.desired_count
  launch_type         = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_groups[each.key].arn
    container_name   = each.key
    container_port   = 8080
  }
}

# ******** lambda section starts ********

resource "aws_s3_bucket" "lambda_logs_bucket" {
  bucket = "my-serverless-logs-bucket-${random_string.suffix.id}" 
  # Utilizamos un random_string para evitar colisiones de nombre
}

resource "aws_s3_bucket_public_access_block" "lambda_logs_bucket" {
  bucket = aws_s3_bucket.lambda_logs_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "lambda_logs_bucket_policy" {
  bucket = aws_s3_bucket.lambda_logs_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyPublicAccess",
        Effect    = "Deny",
        Principal = "*",
        Action    = ["s3:GetObject", "s3:ListBucket"],
        Resource  = [
          "${aws_s3_bucket.lambda_logs_bucket.arn}",
          "${aws_s3_bucket.lambda_logs_bucket.arn}/*"
        ],
        Condition = {
          Bool: {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  })
}

resource "random_string" "suffix" {
  length = 8
  special = false
  upper = false
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_index.py"
  output_path = "${path.module}/lambda_function_payload.zip"
}

resource "aws_lambda_function" "monitor_services_lambda" {
  function_name = "monitor-services-lambda"
  handler       = "lambda_index.handler"
  runtime       = "python3.9"
  role          = "arn:aws:iam::905418052472:role/LabRole"  # Ajustar si hace falta

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      PRODUCTS_SERVICE_URL = "products-service-alb-1661164233.us-east-1.elb.amazonaws.com"
      ORDERS_SERVICE_URL   = "orders-service-alb-2116084825.us-east-1.elb.amazonaws.com"
      SHIPPING_SERVICE_URL = "shipping-service-alb-1784245012.us-east-1.elb.amazonaws.com"
      S3_BUCKET            = aws_s3_bucket.lambda_logs_bucket.bucket
    }
  }
}

resource "aws_cloudwatch_event_rule" "monitor_services_rule" {
  name                 = "monitor-services-every-5-min"
  description          = "Invoca la lambda cada 5 minutos para monitorear los servicios"
  schedule_expression  = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "monitor_services_target" {
  rule      = aws_cloudwatch_event_rule.monitor_services_rule.name
  target_id = "invoke-lambda"
  arn       = aws_lambda_function.monitor_services_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_monitor_services" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.monitor_services_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monitor_services_rule.arn
}


# ******** lambda section ends ********

output "alb_dns_names" {
  value = { for name, alb in aws_lb.application_lbs : name => alb.dns_name }
}
