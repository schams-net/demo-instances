resource "aws_default_security_group" "typo3_demo" {
    #name = "${var.tag_name}-vpc"
    vpc_id = aws_vpc.typo3_demo.id
    tags = {
        Name = "${var.tag_name} - VPC"
        billing-id = var.tag_billing_id
    }
}
