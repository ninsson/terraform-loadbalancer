data "aws_vpc" "selected" {
  tags = {
    Name = var.vpc_name
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "cidr-block"
    values = ["10.0.1.0/24", "10.0.3.0/24"]
  }
}

data "aws_security_group" "ec2" {
  name   = var.ec2_sg_name
  vpc_id = data.aws_vpc.selected.id
}

data "aws_security_group" "http" {
  name   = var.http_sg_name
  vpc_id = data.aws_vpc.selected.id
}

data "aws_security_group" "alb" {
  name   = var.alb_sg_name
  vpc_id = data.aws_vpc.selected.id
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


resource "aws_launch_template" "main" {
  name          = var.launch_template_name
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
    delete_on_termination = true
    security_groups = [
      data.aws_security_group.ec2.id,
      data.aws_security_group.http.id
    ]
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd jq
              systemctl enable httpd
              systemctl start httpd

              TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
              PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

              cat <<HTML > /var/www/html/index.html
              <!DOCTYPE html>
              <html>
              <head><title>App Server</title></head>
              <body>
                <h1>Instance Details</h1>
                <p>Instance ID: $INSTANCE_ID</p>
                <p>Private IP: $PRIVATE_IP</p>
              </body>
              </html>
              HTML
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Terraform = "true"
      Project   = var.project_id
    }
  }

  tags = {
    Terraform = "true"
    Project   = var.project_id
  }
}

resource "aws_autoscaling_group" "main" {
  name                = var.asg_name
  desired_capacity    = 2
  min_size            = 1
  max_size            = 2
  vpc_zone_identifier = data.aws_subnets.public.ids

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  lifecycle {
    ignore_changes = [load_balancers, target_group_arns]
  }

  tag {
    key                 = "Terraform"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_id
    propagate_at_launch = true
  }
}

resource "aws_lb_target_group" "main" {
  name     = var.target_group_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.selected.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Terraform = "true"
    Project   = var.project_id
  }
}

resource "aws_autoscaling_attachment" "main" {
  autoscaling_group_name = aws_autoscaling_group.main.id
  lb_target_group_arn    = aws_lb_target_group.main.arn
}

resource "aws_lb" "main" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_security_group.alb.id]
  subnets            = data.aws_subnets.public.ids

  tags = {
    Terraform = "true"
    Project   = var.project_id
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = {
    Terraform = "true"
    Project   = var.project_id
  }
}