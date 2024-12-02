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
      
      environment = [
        {
          name  = "PAYMENTS_SERVICE_URL"
          value = "http://payments-service-alb-1611589606.us-east-1.elb.amazonaws.com"
        },
        {
          name  = "SHIPPING_SERVICE_URL"
          value = "http://shipping-service-alb-15976227.us-east-1.elb.amazonaws.com"
        },
        {
          name  = "PRODUCTS_SERVICE_URL"
          value = "http://products-service-alb-110946858.us-east-1.elb.amazonaws.com"
        }
      ]
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
  bucket = "fe-app-s3"

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

output "alb_dns_names" {
  value = { for name, alb in aws_lb.application_lbs : name => alb.dns_name }
}
