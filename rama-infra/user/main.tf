provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "rama_aws_deploy" {
  bucket = "rama-aws-deploy"
  acl = "private"
}
