resource "aws_key_pair" "typo3_demo" {
    key_name = "TYPO3 Demo Instance"
    public_key = file("assets/keys/example.pub")
}
