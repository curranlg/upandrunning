provider "aws" { 
    region = "us-east-2" 
}


resource "aws_instance" "ec2-instance1" { 
    ami = "ami-0c55b159cbfafe1f0" 
    instance_type = "t2.micro" 
    vpc_security_group_ids = [aws_security_group.SG1.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello World!" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF

    tags = {
        Name = "terraform-example"
    }
    } 


resource "aws_security_group" "SG1" { 
    name = "terraform-example-sg" 
    ingress { 
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp" 
        cidr_blocks = [ "0.0.0.0/0" ] 
        } 
} 


