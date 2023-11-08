provider "aws" {
  region = "us-west-2"
}

// todo need permissions to run and verify
//resource "aws_iam_role" "deployed_supervisor_node" {
//  name               = "deployed-supervisor-node"
//  assume_role_policy = file("policy-assume-role.json")
//}
//
//resource "aws_iam_policy" "s3_access_policy" {
//  name        = "s3-access-policy"
//  policy      = file("policy-allow-s3.json")
//}
//
//resource "aws_iam_policy_attachment" "s3_policy_attach" {
//  name       = "aaron-test-attach"
//  roles      = [aws_iam_role.deployed_supervisor_node.name]
//  policy_arn = aws_iam_policy.s3_access_policy.arn
//}
