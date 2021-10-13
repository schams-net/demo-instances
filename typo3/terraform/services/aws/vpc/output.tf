output "vpc_id" {
    value = aws_vpc.typo3_demo.id
}

output "public_zone_a" {
    value = aws_subnet.public_zone_a.id
}

output "public_zone_b" {
    value = aws_subnet.public_zone_b.id
}

output "public_zone_c" {
    value = aws_subnet.public_zone_c.id
}
