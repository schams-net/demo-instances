output "ec2_public_ip" {
    value = aws_instance.debian11.public_ip
}
