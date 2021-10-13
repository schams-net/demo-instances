resource "aws_subnet" "public_zone_a" {
    vpc_id = aws_vpc.typo3_demo.id
    availability_zone = var.availability_zones[0]
    cidr_block = "10.10.10.0/24"
    ipv6_cidr_block = cidrsubnet(aws_vpc.typo3_demo.ipv6_cidr_block, 8, 1)
    assign_ipv6_address_on_creation = true
    tags = {
        Name = "${var.tag_name} - public subnet, zone A"
        billing-id = var.tag_billing_id
    }
}

resource "aws_subnet" "public_zone_b" {
    vpc_id = aws_vpc.typo3_demo.id
    availability_zone = var.availability_zones[1]
    cidr_block = "10.10.20.0/24"
    ipv6_cidr_block = cidrsubnet(aws_vpc.typo3_demo.ipv6_cidr_block, 8, 2)
    assign_ipv6_address_on_creation = true
    tags = {
        Name = "${var.tag_name} - public subnet, zone B"
        billing-id = var.tag_billing_id
    }
}

resource "aws_subnet" "public_zone_c" {
    vpc_id = aws_vpc.typo3_demo.id
    availability_zone = var.availability_zones[2]
    cidr_block = "10.10.30.0/24"
    ipv6_cidr_block = cidrsubnet(aws_vpc.typo3_demo.ipv6_cidr_block, 8, 3)
    assign_ipv6_address_on_creation = true
    tags = {
        Name = "${var.tag_name} - public subnet, zone C"
        billing-id = var.tag_billing_id
    }
}
