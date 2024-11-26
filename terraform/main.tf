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

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "backend-ecs-cluster"
}

resource "aws_ecs_task_definition" "task_definition" {
  for_each = toset(var.service_names)

  family                   = each.key
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # Adjust as per service needs
  memory                   = "512" # Adjust as per service needs

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = "${var.dockerhub_username}/${each.key}:latest" # Placeholder image, CI/CD will deploy the real one
      essential = true
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_lb" "application_lb" {
  name               = "backend-app-lb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg.id]
  subnets            = data.aws_subnets.public.ids

  tags = {
    Name = "backend-app-lb"
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
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.application_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404 Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "service_rules" {
  for_each     = toset(var.service_names)
  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 100 + index(var.service_names, each.key)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_groups[each.key].arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}/*"]
    }
  }
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

  depends_on = [aws_lb_listener_rule.service_rules]
}

output "alb_dns_name" {
  value = aws_lb.application_lb.dns_name
}