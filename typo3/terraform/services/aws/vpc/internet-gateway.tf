resource "aws_internet_gateway" "typo3_demo" {
    vpc_id = aws_vpc.typo3_demo.id
    tags = {
        Name = var.tag_name
        billing-id = var.tag_billing_id
    }
}
