data "archive_file" "assets_ec2" {
    source_dir = "assets/ec2/"
    type = "zip"
    output_path = "temp/ec2.zip"
}
