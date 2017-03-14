/*
Using Terraform on the file two commands need to be run.

Terraform plan
Terraform apply
*/

provider "aws" {
  region     = "us-east-1"  # region where the EC2 instance will be deployed
  access_key = "USER_KEY"   # Replace with User key that has EC2 Deployment 
  secret_key = "USER_PASS"  # Replace with Secret key from user creation 
}

resource "aws_instance" "auto" {               # auto is the name of the resource to be used if executing multiple resources
  ami           = "USER_SNAPSHOT_OR_AWS_AMI"   # Can create an EC2 instance from either a user defined snapshot added to AWS owned by user or from an AWS AMI
  instance_type = "t2.micro"                   # EC2 Instance type to deploy based on budget or requirements
  key_name      = "SSH_KEY"                    # A means to connect to the EC2 instance
}
