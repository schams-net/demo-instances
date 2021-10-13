resource "aws_instance" "debian11" {
    ami = data.aws_ami.debian11.id
    instance_type = "t3.micro"
    associate_public_ip_address = true

    vpc_security_group_ids = [ aws_security_group.typo3_demo.id ]
    subnet_id = var.public_zone_a
    iam_instance_profile = var.aws_iam_instance_profile

    key_name = aws_key_pair.typo3_demo.id
    user_data = data.template_file.user_data.rendered
    instance_initiated_shutdown_behavior = "stop"
    #instance_initiated_shutdown_behavior = "terminate"

    root_block_device {
        volume_type = "gp2"
        volume_size = var.volume_size
        delete_on_termination = true
    }

    provisioner "file" {
        source = "temp/ec2.zip"
        destination = "/tmp/assets.zip"
        connection {
            type = "ssh"
            user = "admin"
            private_key = file("~/.ssh/id_rsa")
            host = self.public_dns
        }
    }

    tags = {
        Name = "${var.tag_name}"
        billing-id = var.tag_billing_id
    }
}
