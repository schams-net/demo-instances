resource "aws_iam_role" "typo3_demo" {
    name = var.tag_name
    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF

    tags = {
        Name = var.tag_name
        billing-id = var.tag_billing_id
    }
}
