resource "aws_route_table" "public" {
    vpc_id = aws_vpc.typo3_demo.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.typo3_demo.id
    }
    route {
        ipv6_cidr_block = "::/0"
        gateway_id = aws_internet_gateway.typo3_demo.id
    }
    tags = {
        Name = var.tag_name
        billing-id = var.tag_billing_id
    }
}

resource "aws_route_table_association" "public_zone_a" {
    subnet_id = aws_subnet.public_zone_a.id
    route_table_id = aws_route_table.public.id
}
