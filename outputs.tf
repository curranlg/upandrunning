output "ec2_public_ip" { 
    value = aws_instance.ec2-instance1.public_ip 
    description = "The public IP address of the web server:" 
} 
