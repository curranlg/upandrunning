/* Commented out as moved from single EC2 instance to ASG
output "ec2_public_ip" { 
    value = aws_instance.ec2-01.public_ip 
    description = "The public IP address of the web server:" 
} 
*/