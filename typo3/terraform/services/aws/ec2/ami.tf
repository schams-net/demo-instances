data "aws_ami" "debian11" {
    most_recent = true
    filter {
        name = "name"
        values = ["debian-11-amd64-*"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
    # owner: Debian
    owners = ["136693071363"]
}
