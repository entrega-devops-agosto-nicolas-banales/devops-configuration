# variables.tf
variable "aws_region" {
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key" {
  type        = string
}

variable "aws_secret_key" {
  type        = string
}

variable "aws_session_token" {
  type        = string
}

variable "dockerhub_username" {
  type        = string
}

variable "image_tag" {
  type        = string
}

variable "service_names" {
  type        = list(string)
  default     = ["orders-service", "payments-service", "products-service", "shipping-service"]
}

variable "desired_count" {
  type        = number
  default     = 1
}
