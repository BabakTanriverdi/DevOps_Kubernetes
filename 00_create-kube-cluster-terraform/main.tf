terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  # change here, optional
  name         = "mykey"
  keyname      = "mod_1_key"
  instancetype = "c7i-flex.large"
  ami          = "ami-0b6c6ebed2801a5cb"
}

resource "aws_instance" "master" {
  ami                    = local.ami
  instance_type          = local.instancetype
  key_name               = local.keyname
  iam_instance_profile   = aws_iam_instance_profile.ec2connectprofile.name
  user_data              = file("master.sh")
  vpc_security_group_ids = [aws_security_group.tf-k8s-master-sec-gr.id]
  tags = {
    Name = "kube-master"
  }
}

resource "aws_instance" "worker" {
  ami                    = local.ami
  instance_type          = local.instancetype
  key_name               = local.keyname
  iam_instance_profile   = aws_iam_instance_profile.ec2connectprofile.name
  vpc_security_group_ids = [aws_security_group.tf-k8s-master-sec-gr.id]
  user_data              = templatefile("worker.sh", { region = data.aws_region.current.name, master-id = aws_instance.master.id, master-zone = aws_instance.master.availability_zone, master-private = aws_instance.master.private_ip })
  tags = {
    Name = "kube-worker"
  }
  root_block_device {
    volume_size = 20          # <-- Set to desired size in GB
    volume_type = "gp3"
  }
  depends_on = [aws_instance.master]
}

resource "aws_iam_instance_profile" "ec2connectprofile" {
  name = "ec2connectprofile-${local.name}2"
  role = aws_iam_role.ec2connectcli.name
}

resource "aws_iam_role" "ec2connectcli" {
  name = "ec2connectcli-${local.name}2"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "ec2connectcli_policy" {
  name = "ec2connectcli-policy-${local.name}"
  role = aws_iam_role.ec2connectcli.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow",
        Action   = "ec2-instance-connect:SendSSHPublicKey",
        Resource = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*",
        Condition = {
          StringEquals = {
            "ec2:osuser" = "ubuntu"
          }
        }
      },
      {
        Effect   = "Allow",
        Action   = ["ec2:DescribeInstances", "ec2:DescribeInstanceStatus"],
        Resource = "*"
      }
    ]
  })
}


resource "aws_security_group" "tf-k8s-master-sec-gr" {
  name = "${local.name}-k8s-master-sec-gr-babak"
  tags = {
    Name = "${local.name}-k8s-master-sec-gr"
  }

  ingress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    self      = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}


output "master_public_dns" {
  value = aws_instance.master.public_dns
}

output "master_private_dns" {
  value = aws_instance.master.private_dns
}

output "worker_public_dns" {
  value = aws_instance.worker.public_dns
}

output "worker_private_dns" {
  value = aws_instance.worker.private_dns
}
