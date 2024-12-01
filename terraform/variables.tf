variable "aws_region" {
  type = string
  default = "us-east-1"
}

variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

variable "aws_session_token" {
  type = string
}

variable "dockerhub_username" {
  type        = string
}

variable "service_names" {
  type    = list(string)
  default = ["payments-service", "products-service", "shipping-service", "orders-service"]
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "service_health_paths" {
  type = map(string)
  default = {
    "products-service" = "/products"
    "orders-service"   = "/"
    "payments-service" = "/"
    "shipping-service" = "/"
  }
}