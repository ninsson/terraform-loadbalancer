variable "aws_region" {
  type        = string
  description = "AWS region for deployment"
}

variable "project_id" {
  type        = string
  description = "Project identifier used for tags"
}

variable "vpc_name" {
  type        = string
  description = "Name of the existing VPC"
}

variable "launch_template_name" {
  type        = string
  description = "Name of the Launch Template"
}

variable "asg_name" {
  type        = string
  description = "Name of the Auto Scaling Group"
}

variable "alb_name" {
  type        = string
  description = "Name of the Application Load Balancer"
}

variable "target_group_name" {
  type        = string
  description = "Name of the Target Group"
}

variable "key_name" {
  type        = string
  description = "Name of the existing Key Pair"
}

variable "instance_profile_name" {
  type        = string
  description = "Name of the existing IAM instance profile"
}

variable "ec2_sg_name" {
  type        = string
  description = "Name of the existing EC2 SSH security group"
}

variable "http_sg_name" {
  type        = string
  description = "Name of the existing EC2 HTTP security group"
}

variable "alb_sg_name" {
  type        = string
  description = "Name of the existing ALB security group"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}