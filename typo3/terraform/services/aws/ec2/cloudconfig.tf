data "template_file" "user_data" {
    template = file("assets/ec2/cloudconfig.yaml")
}
