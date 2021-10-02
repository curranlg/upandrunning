# Examples from Terraform - Up and Running
# Liam Curran
# Version 0.1
# 22/08/2020

# Define the provider as AWS and set the Region
provider "aws" { 
    region = "us-east-2" 
    version = "~> 3.0"
}

# Set terraform backend to use S3 bucket
terraform {
    backend "s3" {
        bucket = "lgc-tf-up-and-running-state-2020"
        key = "global/s3/terraform.tfstate"
        region = "us-east-2"
        dynamodb_table = "terraform_locks"
        encrypt = true
    }
}

# Define the Security Group
resource "aws_security_group" "SG1" { 
    name = "terraform-example-sg" 
    ingress { 
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp" 
        cidr_blocks = [ "0.0.0.0/0" ] 
        } 
} 

# Define the ASG launch configuration
resource "aws_launch_configuration" "asg-lc01" { 
    image_id = "ami-0c55b159cbfafe1f0" 
    instance_type = "t2.micro"
    security_groups = [aws_security_group.SG1.id]
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello World, from Terraform up and running" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF
    
    lifecycle {
    # Required when using a launch configuration with an auto scaling group
    # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html 
    
        create_before_destroy = true
    }
}

# Define the Auto Scaling Group (ASG)
resource "aws_autoscaling_group" "asg01" {
    launch_configuration = aws_launch_configuration.asg-lc01.name
    vpc_zone_identifier  = data.aws_subnet_ids.vpc_sn_ids.ids
    target_group_arns = [aws_lb_target_group.alb-tg-01.arn]
    health_check_type = "ELB"
    min_size = 2
    max_size = 10

    tag {
        key = "Name"
        value = "terraform-asg-example"
        propagate_at_launch = true
    }

    lifecycle {
    # Required when using a launch configuration with an auto scaling group
    # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html 
    
        create_before_destroy = true
    }
}

# Grab reference to the default VPC
data "aws_vpc" "default_vpc" {
    default = true
}
# Grab the subnet id's from the default VPC
data "aws_subnet_ids" "vpc_sn_ids" {
    vpc_id = data.aws_vpc.default_vpc.id
}

# Create the ALB across all default VPC subnets
resource "aws_lb" "alb01" {
    name = "terraform-asg-example"
    load_balancer_type = "application"
    subnets = data.aws_subnet_ids.vpc_sn_ids.ids
    security_groups = [aws_security_group.sg-alb-01.id]
}

# Create the ALB HTTP listener
resource "aws_lb_listener" "listener01" {
    load_balancer_arn = aws_lb.alb01.arn
    port = 80
    protocol = "HTTP"

    # By default, return a simple 404 page
    default_action {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "404: page not found"
        status_code = "404"
      }
    }
}

# Create Security Group for the ALB
resource "aws_security_group" "sg-alb-01" {
    name = "terraform-example-alb"

    # Allow inbound HTTP from the Internet
    ingress {
        cidr_blocks = ["0.0.0.0/0"]
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        description = "Allow HTTP traffic from the Internet"
  }
    # Allow all outbound requests
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the target group
resource "aws_lb_target_group" "alb-tg-01" {
    name = "terraform-asg-tg-example"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default_vpc.id

    health_check {
      path = "/"
      protocol = "HTTP"
      matcher = "200"
      interval = 15
      timeout = 3
      healthy_threshold = 2
      unhealthy_threshold = 2
    }
}

# Create the ALB Listener Rule 
resource "aws_lb_listener_rule" "alb-lr-01" {
    listener_arn = aws_lb_listener.listener01.arn
    priority = 100

    condition {
        path_pattern {
          values = ["*"]
        }
    }
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.alb-tg-01.arn
    }
}

# New function