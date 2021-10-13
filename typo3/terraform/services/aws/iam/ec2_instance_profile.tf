resource "aws_iam_instance_profile" "ec2_instance_profile" {
    name = var.tag_name
    role = aws_iam_role.typo3_demo.id
}
