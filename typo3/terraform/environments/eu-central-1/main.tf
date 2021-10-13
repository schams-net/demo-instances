# ...
module "aws_iam" {
    source = "../../services/aws/iam"

    tag_name = var.tag_name
    tag_billing_id = var.tag_billing_id
}

# ...
module "aws_vpc" {
    source = "../../services/aws/vpc"

    availability_zones = var.availability_zones

    tag_name = var.tag_name
    tag_billing_id = var.tag_billing_id
}

# ...
module "aws_ec2" {
    source = "../../services/aws/ec2"

    vpc_id = module.aws_vpc.vpc_id
    public_zone_a = module.aws_vpc.public_zone_a
    public_zone_b = module.aws_vpc.public_zone_b
    public_zone_c = module.aws_vpc.public_zone_c
    aws_iam_instance_profile = module.aws_iam.instance_profile
    volume_size = var.volume_size

    tag_name = var.tag_name
    tag_billing_id = var.tag_billing_id
}
