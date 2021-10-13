resource "aws_vpc" "typo3_demo" {
    cidr_block = "10.10.0.0/16"
    instance_tenancy = "default"
    enable_dns_support = true
    enable_dns_hostnames = true
    assign_generated_ipv6_cidr_block = true
    tags = {
        Name = var.tag_name
        billing-id = var.tag_billing_id
    }
}
