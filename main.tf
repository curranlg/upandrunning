# Examples from Terraform - Up and Running
# Liam Curran
# Version 0.1
# 22/08/2020

# Define the provider as AWS and set the Region
provider "aws" { 
    region = "us-east-2" 
    version = "~> 3.0"
}

# Grab the default VPC
data "aws_vpc" "default-vpc" {
    default = true
}

# Grab the subnet id's from default VPC
data "aws_subnet_ids" "subnet_ids" {
    vpc_id = data.aws_vpc.default-vpc.id
}

# Define the Auto Scaling Group launch configuration
resource "aws_launch_configuration" "ASG-launch-config" { 
    image_id = "ami-0c55b159cbfafe1f0" 
    instance_type = "t2.micro" 
    security_groups = [aws_security_group.SG1.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello World!" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF

# Required when using a launch configuration with an auto scaling group. 
# https://www.terraform.io/docs/providers/aws/r/launch_configuration.html 
lifecycle { create_before_destroy = true }


} 

# Define the Auto Scaling Group
resource "aws_autoscaling_group" "ASG1" { 
    launch_configuration = aws_launch_configuration.ASG-launch-config.name 
    vpc_zone_identifier = data.aws_subnet_ids.subnet_ids.ids
    min_size = 2 
    max_size = 10 
    tag { 
         key = "Name" 
         value = "terraform-asg-example" 
         propagate_at_launch = true 
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


