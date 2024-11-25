# main.tf

provider "aws" {
  region         = var.aws_region
  access_key     = var.aws_access_key
  secret_key     = var.aws_secret_key
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

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group para el Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id

  ingress {
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

resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.public.ids

  tags = {
    Name = "app-lb"
  }
}

resource "aws_lb_target_group" "tg" {
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
    unhealthy_threshold = 2
    healthy_threshold   = 2
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "listener_rule" {
  for_each        = toset(var.service_names)
  listener_arn    = aws_lb_listener.app_listener.arn
  priority        = 100 + index(var.service_names, each.key)
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[each.key].arn
  }
  
  condition {
    path_pattern {
      patterns = ["/${each.key}/*"]
    }
  }
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-ecs-cluster"
}

resource "aws_security_group" "ecs_tasks_sg" {
  name        = "ecs-tasks-sg"
  description = "Security group para las tareas ECS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
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
      image     = "${var.dockerhub_username}/${each.key}:${var.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = each.key == "orders-service" ? [
        {
          name  = "PAYMENTS_SERVICE_ENDPOINT"
          value = "http://${aws_lb.app_lb.dns_name}/payments-service/"
        },
        {
          name  = "PRODUCTS_SERVICE_ENDPOINT"
          value = "http://${aws_lb.app_lb.dns_name}/products-service/"
        },
        {
          name  = "SHIPPING_SERVICE_ENDPOINT"
          value = "http://${aws_lb.app_lb.dns_name}/shipping-service/"
        }
      ] : null
    }
  ])
}

resource "aws_ecs_service" "ecs_service" {
  for_each            = aws_ecs_task_definition.task_definition
  name                = each.key
  cluster             = aws_ecs_cluster.ecs_cluster.id
  task_definition     = each.value.arn
  desired_count       = var.desired_count
  launch_type         = "FARGATE"
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = data.aws_subnets.public.ids
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg[each.key].arn
    container_name   = each.key
    container_port   = 8080
  }

  depends_on = [aws_lb_listener_rule.listener_rule]
}

output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
}
